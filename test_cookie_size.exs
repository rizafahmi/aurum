# Test: Risk #5 — Encrypted Cookie Size Limits
# Run with: mix run test_cookie_size.exs
#
# WHAT COULD GO WRONG:
# - Cookie > 4KB: Browser silently drops it, user sees "logged out"
# - Cookie > 8KB: Some CDNs (Cloudflare) reject entire request
# - Adding more fields later: Could push over limit unexpectedly
# - Different encryption keys: Size varies slightly per environment

alias Plug.Crypto

# Simulate what we'd store in a session cookie
vault_id = Ecto.UUID.generate()                        # 36 bytes
vault_token = :crypto.strong_rand_bytes(32) |> Base.encode64()  # 44 bytes base64
user_scope_id = Ecto.UUID.generate()                   # 36 bytes

session_data = %{
  "vault_id" => vault_id,
  "vault_token" => vault_token,
  "current_scope_id" => user_scope_id,
  "_csrf_token" => Base.encode64(:crypto.strong_rand_bytes(16))  # 24 bytes
}

IO.puts("=== Risk #5: Encrypted Cookie Size Test ===\n")
IO.puts("Session data (raw):")
IO.inspect(session_data, pretty: true)
IO.puts("\nRaw JSON size: #{byte_size(Jason.encode!(session_data))} bytes")

# Phoenix uses a 64-byte secret_key_base (we simulate one)
secret_key_base = :crypto.strong_rand_bytes(64) |> Base.encode64()

# Derive signing and encryption keys like Phoenix does
signing_salt = "signed encrypted cookie"
encryption_salt = "encrypted cookie"

# Phoenix.Token style encryption (what Plug.Session uses internally)
# This mimics what happens in Plug.Session.COOKIE
secret = Plug.Crypto.KeyGenerator.generate(secret_key_base, encryption_salt, iterations: 1000)
sign_secret = Plug.Crypto.KeyGenerator.generate(secret_key_base, signing_salt, iterations: 1000)

# Encrypt the session (MessageEncryptor with AES-256-GCM)
encrypted = Plug.Crypto.MessageEncryptor.encrypt(
  Jason.encode!(session_data),
  <<>>,  # no associated data
  secret,
  sign_secret
)

# Base64 encode for cookie transport
cookie_value = Base.url_encode64(encrypted, padding: false)

IO.puts("\n=== RESULTS ===")
IO.puts("Encrypted cookie size: #{byte_size(cookie_value)} bytes")
IO.puts("Browser limit (4KB):   4096 bytes")
IO.puts("CDN header limit:      ~8192 bytes")
IO.puts("")

remaining = 4096 - byte_size(cookie_value)
IO.puts("Headroom before 4KB limit: #{remaining} bytes")

if byte_size(cookie_value) < 4096 do
  IO.puts("\n✅ PASS: Cookie fits within 4KB browser limit")
else
  IO.puts("\n❌ FAIL: Cookie exceeds 4KB limit!")
end

# Round-trip test: verify we can decrypt it
IO.puts("\n=== Round-trip Test ===")
decoded = Base.url_decode64!(cookie_value, padding: false)
{:ok, decrypted_json} = Plug.Crypto.MessageEncryptor.decrypt(decoded, <<>>, secret, sign_secret)
decrypted_data = Jason.decode!(decrypted_json)

if decrypted_data == session_data do
  IO.puts("✅ PASS: Decrypted data matches original")
else
  IO.puts("❌ FAIL: Data mismatch after decrypt!")
  IO.inspect(decrypted_data, label: "Got")
end

# Stress test: How much can we add before hitting limit?
IO.puts("\n=== Capacity Test ===")
IO.puts("Testing how many extra UUIDs we can add before hitting 4KB...")

test_data = session_data
count = 0

Stream.iterate(0, &(&1 + 1))
|> Enum.reduce_while(test_data, fn i, acc ->
  acc = Map.put(acc, "extra_#{i}", Ecto.UUID.generate())
  enc = Plug.Crypto.MessageEncryptor.encrypt(Jason.encode!(acc), <<>>, secret, sign_secret)
  size = byte_size(Base.url_encode64(enc, padding: false))

  if size < 4096 do
    {:cont, acc}
  else
    IO.puts("Hit 4KB limit after adding #{i} extra UUIDs")
    IO.puts("Each UUID adds ~60-70 bytes to encrypted cookie")
    {:halt, acc}
  end
end)

IO.puts("\n=== Summary ===")
IO.puts("Base session size: #{byte_size(cookie_value)} bytes")
IO.puts("Plenty of room for vault_id + vault_token + typical session data")
