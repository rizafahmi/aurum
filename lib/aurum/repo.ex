defmodule Aurum.Repo do
  @moduledoc """
  Dynamic Ecto repository for per-vault SQLite databases.

  In multi-vault mode, each user has their own SQLite database.
  The correct repo is bound at request/LiveView mount time via
  `Aurum.VaultDatabase.DynamicRepo` and `AurumWeb.VaultHooks`.
  """

  use Ecto.Repo,
    otp_app: :aurum,
    adapter: Ecto.Adapters.SQLite3

  @doc """
  Returns the database path for a given vault_id.
  """
  def vault_database_path(vault_id) do
    Aurum.VaultDatabase.Manager.vault_path(vault_id)
  end
end
