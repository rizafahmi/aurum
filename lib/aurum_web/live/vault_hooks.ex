defmodule AurumWeb.VaultHooks do
  @moduledoc """
  LiveView hooks for vault-scoped database access.

  Ensures each LiveView session uses the correct per-vault database.
  """

  import Phoenix.Component, only: [assign: 3]

  alias Aurum.VaultRepo

  @doc """
  on_mount callback that binds the vault's database repo.

  Reads `vault_id` from session (set by VaultPlug) and ensures
  all Repo operations in this LiveView use that vault's database.
  """
  def on_mount(:default, _params, session, socket) do
    vault_id = session["vault_id"]

    if vault_id do
      {:ok, _pid} = VaultRepo.ensure_repo_started(vault_id)

      unless Application.get_env(:aurum, :env) == :test do
        Aurum.Repo.put_dynamic_repo(VaultRepo.repo_name(vault_id))
      end

      {:cont, assign(socket, :vault_id, vault_id)}
    else
      {:cont, socket}
    end
  end
end
