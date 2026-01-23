defmodule AurumWeb.SettingsController do
  use AurumWeb, :controller

  alias Aurum.VaultDatabase.Manager

  def export(conn, _params) do
    vault_id = conn.private[:vault_id]

    case Manager.export_database(vault_id) do
      {:ok, temp_path} ->
        # Read file content before sending (allows cleanup)
        content = File.read!(temp_path)
        File.rm(temp_path)

        conn
        |> put_resp_content_type("application/x-sqlite3")
        |> put_resp_header("content-disposition", ~s(attachment; filename="vault_#{vault_id}.db"))
        |> put_resp_header("cache-control", "no-store")
        |> send_resp(200, content)

      {:error, :not_found} ->
        conn
        |> put_flash(:error, "Vault database not found")
        |> redirect(to: ~p"/settings")

      {:error, _reason} ->
        conn
        |> put_flash(:error, "Export failed")
        |> redirect(to: ~p"/settings")
    end
  end
end
