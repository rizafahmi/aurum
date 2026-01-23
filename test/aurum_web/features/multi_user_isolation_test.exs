defmodule AurumWeb.MultiUserIsolationTest do
  use AurumWeb.ConnCase, async: false

  @moduletag :vault_feature

  describe "US-103: Multi-User Isolation" do
    test "two users in different browsers get different vault IDs", %{conn: conn} do
      # User 1: Creates vault on first visit
      conn1 = get(conn, "/")
      user1_vault_id = conn1.private[:vault_credentials].vault_id

      assert user1_vault_id != nil, "Expected vault_id to be set"
      assert {:ok, _} = Ecto.UUID.cast(user1_vault_id), "Expected valid UUID"

      # User 2: Creates a new vault (different browser, no cookie)
      conn2 = get(build_conn(), "/")
      user2_vault_id = conn2.private[:vault_credentials].vault_id

      assert user2_vault_id != nil, "Expected vault_id to be set for second user"
      assert {:ok, _} = Ecto.UUID.cast(user2_vault_id), "Expected valid UUID"

      # Verify different vault IDs
      refute user1_vault_id == user2_vault_id,
             "Expected different vault IDs for different users"

      # Verify vault records exist in central database
      assert Aurum.Accounts.Repo.get(Aurum.Accounts.Vault, user1_vault_id) != nil
      assert Aurum.Accounts.Repo.get(Aurum.Accounts.Vault, user2_vault_id) != nil
    end

    test "each vault gets its own database file", %{conn: conn} do
      # Create two separate vaults
      conn1 = get(conn, "/")
      vault1_id = conn1.private[:vault_credentials].vault_id

      conn2 = get(build_conn(), "/")
      vault2_id = conn2.private[:vault_credentials].vault_id

      # Verify different vault IDs
      refute vault1_id == vault2_id

      # Verify separate database paths are generated
      path1 = Aurum.VaultDatabase.Manager.vault_path(vault1_id)
      path2 = Aurum.VaultDatabase.Manager.vault_path(vault2_id)

      refute path1 == path2, "Expected different database paths"
      assert path1 =~ vault1_id, "Path should contain vault ID"
      assert path2 =~ vault2_id, "Path should contain vault ID"

      # Verify files were created
      assert File.exists?(path1)
      assert File.exists?(path2)
    end

    test "invalid vault_id cannot access existing vault", %{conn: conn} do
      # Create a legitimate vault
      conn1 = get(conn, "/")
      legitimate_vault_id = conn1.private[:vault_credentials].vault_id

      # Attempt to access with forged/invalid vault credentials
      forged_vault_id = Ecto.UUID.generate()

      forged_cookie_value =
        Jason.encode!(%{
          vault_id: forged_vault_id,
          token: "invalid_token_attempt"
        })

      # Request with forged cookie should create a new vault (not access existing)
      conn2 =
        build_conn()
        |> put_req_cookie("_aurum_vault", forged_cookie_value)
        |> get("/")

      # Should get a new vault ID (forged credentials rejected, new vault created)
      new_vault_id = conn2.private[:vault_credentials].vault_id

      refute new_vault_id == legitimate_vault_id,
             "Forged credentials should not access legitimate vault"

      refute new_vault_id == forged_vault_id,
             "Forged vault ID should not be accepted"

      # Verify the new vault is different from both
      assert Aurum.Accounts.Repo.get(Aurum.Accounts.Vault, new_vault_id) != nil,
             "New vault should be created"
    end

    test "concurrent vault creation succeeds without conflicts", %{conn: _conn} do
      # Simulate concurrent first-time visits
      tasks =
        for _i <- 1..5 do
          Task.async(fn ->
            build_conn()
            |> get("/")
          end)
        end

      results = Task.await_many(tasks, 5000)

      # All requests should succeed
      for resp <- results do
        assert resp.status == 200
        assert resp.private[:vault_credentials].vault_id != nil
      end

      # All vault IDs should be unique
      vault_ids = Enum.map(results, & &1.private[:vault_credentials].vault_id)
      assert length(Enum.uniq(vault_ids)) == 5, "All vault IDs should be unique"

      # All vault records should exist
      for vault_id <- vault_ids do
        assert Aurum.Accounts.Repo.get(Aurum.Accounts.Vault, vault_id) != nil
      end
    end

    test "vault databases are separate files", %{conn: conn} do
      # Create two vaults
      conn1 = get(conn, "/")
      vault1_id = conn1.private[:vault_credentials].vault_id

      conn2 = get(build_conn(), "/")
      vault2_id = conn2.private[:vault_credentials].vault_id

      # Verify separate database files exist
      vault1_path = Aurum.VaultDatabase.Manager.vault_path(vault1_id)
      vault2_path = Aurum.VaultDatabase.Manager.vault_path(vault2_id)

      refute vault1_path == vault2_path,
             "Expected different database paths for different vaults"

      assert File.exists?(vault1_path),
             "Expected vault 1 database file to exist at #{vault1_path}"

      assert File.exists?(vault2_path),
             "Expected vault 2 database file to exist at #{vault2_path}"
    end
  end
end
