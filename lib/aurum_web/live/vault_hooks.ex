defmodule AurumWeb.VaultHooks do
  @moduledoc """
  LiveView hooks for vault-scoped database access.

  Ensures each LiveView session uses the correct per-vault database.
  """

  import Phoenix.Component, only: [assign: 3]

  alias Aurum.Env
  alias Aurum.VaultDatabase.DynamicRepo

  @doc """
  on_mount callback that binds the vault's database repo.

  Reads `vault_id` from session (set by VaultPlug) and ensures
  all Repo operations in this LiveView use that vault's database.
  """
  def on_mount(:default, _params, session, socket) do
    vault_id = session["vault_id"]

    if vault_id do
      unless Env.test?() do
        {:ok, repo_pid} = DynamicRepo.get_repo_pid(vault_id)
        Aurum.Repo.put_dynamic_repo(repo_pid)
      end

      {:cont, assign(socket, :vault_id, vault_id)}
    else
      {:cont, socket}
    end
  end
end
