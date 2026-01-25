defmodule AurumWeb.VaultDatabaseExportTest do
  use AurumWeb.ConnCase, async: false

  describe "US-104: Vault Database Export" do
    test "export button available in settings", %{conn: conn} do
      conn
      |> visit("/settings")
      |> assert_has("a", text: "Export Database")
    end

    test "downloads .db file with vault data", %{conn: conn} do
      # Visit settings first to establish session/vault with cookies
      _session = conn |> visit("/settings")

      # Make a separate HTTP request to export endpoint
      # The first request establishes the vault, then we recycle the conn for the export
      export_conn =
        conn
        |> get("/settings")
        |> recycle()
        |> get("/settings/export")

      assert export_conn.status == 200

      content_type = get_resp_header(export_conn, "content-type") |> List.first()
      assert content_type =~ "application/x-sqlite3"
    end

    test "filename includes vault identifier", %{conn: conn} do
      # Get vault and export
      export_conn =
        conn
        |> get("/settings")
        |> recycle()
        |> get("/settings/export")

      # Get the vault_id from the session
      vault_id = export_conn.private[:vault_id]

      # Verify content-disposition header contains vault identifier
      content_disposition = get_resp_header(export_conn, "content-disposition") |> List.first()
      assert content_disposition =~ "attachment"
      assert content_disposition =~ "vault_#{vault_id}.db"
    end

    test "exported file is valid SQLite database", %{conn: conn} do
      # Create test data first
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Export Test Gold Bar")
      |> fill_in("Weight (grams)", with: "100.0")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "5000.00")
      |> click_button("Add Asset")

      # Export the database
      export_conn =
        conn
        |> get("/items")
        |> recycle()
        |> get("/settings/export")

      assert export_conn.status == 200

      # Verify exported file starts with SQLite header magic bytes
      assert String.starts_with?(export_conn.resp_body, "SQLite format 3")
    end
  end
end
