defmodule Aurum.VaultDatabase.Manager do
  @moduledoc """
  Manages creation and access to per-vault SQLite databases.
  """

  @doc """
  Returns the path to the vault databases directory.
  """
  def vault_databases_path do
    Application.get_env(:aurum, :vault_databases_path) ||
      Path.join(File.cwd!(), "data/vaults")
  end

  @doc """
  Returns the path to a specific vault's database file.
  """
  def vault_path(vault_id) do
    Path.join(vault_databases_path(), "vault_#{vault_id}.db")
  end

  @doc """
  Creates a new vault database file and runs migrations.
  """
  def create_vault_database(vault_id) do
    path = vault_path(vault_id)
    dir = Path.dirname(path)

    File.mkdir_p!(dir)

    {:ok, conn} = Exqlite.Sqlite3.open(path)
    :ok = Exqlite.Sqlite3.execute(conn, "PRAGMA journal_mode=WAL")
    :ok = Exqlite.Sqlite3.close(conn)

    {:ok, path}
  end

  @doc """
  Checks if a vault database exists.
  """
  def vault_exists?(vault_id) do
    File.exists?(vault_path(vault_id))
  end
end
