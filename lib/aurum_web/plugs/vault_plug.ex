defmodule AurumWeb.VaultPlug do
  @moduledoc """
  Plug that ensures every request has an associated vault.
  Creates a new vault on first visit, refreshes cookie TTL on return visits.
  """

  import Plug.Conn

  alias Aurum.Accounts
  alias Aurum.VaultDatabase.Manager
  alias Aurum.VaultRepo

  @cookie_name "_aurum_vault"
  @cookie_max_age 365 * 24 * 60 * 60

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, vault_id, token} <- get_vault_from_cookie(conn),
         {:ok, _vault} <- Accounts.verify_vault(vault_id, token) do
      conn
      |> put_vault_cookie(vault_id, token)
      |> put_vault_private(vault_id)
    else
      _ -> create_vault_and_set_cookie(conn)
    end
  end

  defp get_vault_from_cookie(conn) do
    conn = fetch_cookies(conn, encrypted: [@cookie_name])

    with cookie_value when is_binary(cookie_value) <- conn.cookies[@cookie_name],
         {:ok, %{"vault_id" => vault_id, "token" => token}} <- Jason.decode(cookie_value),
         {:ok, _uuid} <- Ecto.UUID.cast(vault_id) do
      {:ok, vault_id, token}
    else
      _ -> :error
    end
  end

  defp create_vault_and_set_cookie(conn) do
    with {:ok, vault, raw_token} <- Accounts.create_vault(),
         {:ok, _path} <- Manager.create_vault_database(vault.id) do
      conn
      |> put_vault_cookie(vault.id, raw_token)
      |> put_vault_private(vault.id)
    else
      {:error, _reason} ->
        conn
        |> put_status(500)
        |> Phoenix.Controller.put_view(AurumWeb.ErrorHTML)
        |> Phoenix.Controller.render("500.html")
        |> halt()
    end
  end

  defp put_vault_cookie(conn, vault_id, token) do
    cookie_value = Jason.encode!(%{vault_id: vault_id, token: token})

    put_resp_cookie(conn, @cookie_name, cookie_value, cookie_opts())
  end

  defp put_vault_private(conn, vault_id) do
    # Ensure the vault's repo is started and bound for this request
    # In test mode, VaultRepo.ensure_repo_started returns the shared sandbox repo
    {:ok, _pid} = VaultRepo.ensure_repo_started(vault_id)

    unless Application.get_env(:aurum, :env) == :test do
      Aurum.Repo.put_dynamic_repo(VaultRepo.repo_name(vault_id))
    end

    conn
    |> put_private(:vault_id, vault_id)
    |> put_private(:vault_credentials, %{vault_id: vault_id})
    |> put_session(:vault_id, vault_id)
  end

  defp cookie_opts do
    [
      encrypt: true,
      max_age: @cookie_max_age,
      http_only: true,
      same_site: "Lax",
      secure: Application.get_env(:aurum, :env) == :prod
    ]
  end
end
