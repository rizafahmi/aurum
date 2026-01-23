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

  @doc """
  Exports a vault database to a temporary file using VACUUM INTO for atomic export.
  Returns {:ok, temp_path} on success.
  """
  def export_database(vault_id) do
    with :ok <- validate_vault_id(vault_id),
         source_path <- vault_path(vault_id),
         true <- File.exists?(source_path) || {:error, :not_found},
         temp_path <- unique_temp_export_path(vault_id),
         :ok <- rm_if_exists(temp_path),
         {:ok, conn} <- Exqlite.Sqlite3.open(source_path) do
      try do
        sql = "VACUUM INTO " <> sqlite_quote_string(temp_path)

        case Exqlite.Sqlite3.execute(conn, sql) do
          :ok -> {:ok, temp_path}
          {:error, reason} -> {:error, reason}
        end
      after
        Exqlite.Sqlite3.close(conn)
      end
    else
      false -> {:error, :not_found}
      {:error, _} = err -> err
    end
  end

  defp validate_vault_id(vault_id) when is_binary(vault_id) do
    case Ecto.UUID.cast(vault_id) do
      {:ok, _} -> :ok
      :error -> {:error, :invalid_vault_id}
    end
  end

  defp validate_vault_id(_), do: {:error, :invalid_vault_id}

  defp unique_temp_export_path(vault_id) do
    filename = "vault_#{vault_id}_export_#{System.unique_integer([:positive])}.db"
    Path.join(System.tmp_dir!(), filename)
  end

  defp rm_if_exists(path) do
    case File.rm(path) do
      :ok -> :ok
      {:error, :enoent} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp sqlite_quote_string(path) do
    escaped = String.replace(path, "'", "''")
    "'" <> escaped <> "'"
  end
end
