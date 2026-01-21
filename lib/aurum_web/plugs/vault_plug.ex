defmodule AurumWeb.VaultPlug do
  @moduledoc """
  Plug that ensures every request has an associated vault.
  Creates a new vault on first visit.
  """

  import Plug.Conn

  alias Aurum.Accounts
  alias Aurum.VaultDatabase.Manager

  @cookie_name "_aurum_vault"
  @cookie_max_age 365 * 24 * 60 * 60

  def init(opts), do: opts

  def call(conn, _opts) do
    case get_vault_from_cookie(conn) do
      {:ok, vault_id, _token} ->
        conn
        |> put_private(:vault_id, vault_id)
        |> put_private(:vault_credentials, %{vault_id: vault_id})

      :error ->
        create_vault_and_set_cookie(conn)
    end
  end

  defp get_vault_from_cookie(conn) do
    conn = fetch_cookies(conn, encrypted: [@cookie_name])

    case conn.cookies[@cookie_name] do
      nil ->
        :error

      cookie_value ->
        case Jason.decode(cookie_value) do
          {:ok, %{"vault_id" => vault_id, "token" => token}} ->
            case Accounts.verify_vault(vault_id, token) do
              {:ok, _vault} -> {:ok, vault_id, token}
              _ -> :error
            end

          _ ->
            :error
        end
    end
  end

  defp create_vault_and_set_cookie(conn) do
    case Accounts.create_vault() do
      {:ok, vault, raw_token} ->
        {:ok, _path} = Manager.create_vault_database(vault.id)

        cookie_value =
          Jason.encode!(%{vault_id: vault.id, token: raw_token})

        conn
        |> put_resp_cookie(@cookie_name, cookie_value,
          encrypt: true,
          max_age: @cookie_max_age,
          http_only: true,
          same_site: "Lax"
        )
        |> put_private(:vault_id, vault.id)
        |> put_private(:vault_credentials, %{vault_id: vault.id})

      {:error, _} ->
        conn
        |> put_status(500)
        |> Phoenix.Controller.put_view(AurumWeb.ErrorHTML)
        |> Phoenix.Controller.render("500.html")
        |> halt()
    end
  end
end
