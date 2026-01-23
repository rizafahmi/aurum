defmodule AurumWeb.AutomaticVaultCreationTest do
  use AurumWeb.ConnCase, async: false

  @moduletag :vault_feature

  describe "US-101: Automatic Vault Creation" do
    test "first visit creates vault without user input", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("#dashboard-content")
    end

    test "vault database file created at expected path", %{conn: conn} do
      conn = get(conn, "/")
      vault_cookie = conn.cookies["_aurum_vault"]

      assert vault_cookie != nil, "Expected vault cookie to be set"

      vault_id = get_vault_id_from_cookie(conn)
      assert vault_id != nil, "Expected vault_id to be extractable from cookie"

      vault_path = vault_database_path(vault_id)
      assert File.exists?(vault_path), "Expected vault database at #{vault_path}"
    end

    test "user sees dashboard within 2 seconds", %{conn: conn} do
      {time_us, conn} = :timer.tc(fn -> get(conn, "/") end)
      time_ms = div(time_us, 1000)

      assert time_ms < 2000, "Expected dashboard within 2 seconds, took #{time_ms}ms"
      assert conn.status == 200, "Expected successful response"
    end

    test "cookie set with vault credentials", %{conn: conn} do
      conn = get(conn, "/")

      vault_cookie = conn.resp_cookies["_aurum_vault"]
      assert vault_cookie != nil, "Expected _aurum_vault cookie to be set"

      assert vault_cookie[:http_only] == true,
             "Expected cookie to be HTTP-only"

      assert vault_cookie[:same_site] == "Lax",
             "Expected SameSite=Lax"

      max_age = vault_cookie[:max_age]
      one_year_seconds = 365 * 24 * 60 * 60

      assert max_age >= one_year_seconds - 86_400,
             "Expected cookie TTL of approximately 1 year"
    end

    test "vault credentials stored in encrypted cookie", %{conn: conn} do
      conn = get(conn, "/")

      raw_cookie_value = conn.resp_cookies["_aurum_vault"].value
      assert raw_cookie_value != nil

      refute raw_cookie_value =~ ~r/[0-9a-f]{8}-[0-9a-f]{4}/i,
             "Raw cookie value should not expose vault_id (should be encrypted)"

      refute raw_cookie_value =~ "vault_id",
             "Raw cookie value should not expose JSON keys (should be encrypted)"
    end

    test "new vault record created in central database", %{conn: conn} do
      initial_count = vault_count()

      get(conn, "/")

      assert vault_count() == initial_count + 1,
             "Expected one new vault record in central database"
    end

    test "vault token hash stored, not plaintext token", %{conn: conn} do
      conn = get(conn, "/")
      vault_id = get_vault_id_from_cookie(conn)

      vault = get_vault_from_central_db(vault_id)
      assert vault != nil, "Expected vault record to exist"

      assert vault.token_hash != nil, "Expected token_hash to be set"

      refute String.length(vault.token_hash) == 64,
             "Token hash should not be raw 32-byte token (64 hex chars)"
    end
  end

  defp vault_database_path(vault_id) do
    Aurum.VaultDatabase.Manager.vault_path(vault_id)
  end

  defp get_vault_id_from_cookie(conn) do
    case conn.private[:vault_credentials] do
      %{vault_id: vault_id} -> vault_id
      _ -> nil
    end
  end

  defp vault_count do
    Aurum.Accounts.Repo.aggregate(Aurum.Accounts.Vault, :count, :id)
  end

  defp get_vault_from_central_db(vault_id) do
    Aurum.Accounts.Repo.get(Aurum.Accounts.Vault, vault_id)
  end
end
