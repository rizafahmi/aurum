defmodule Aurum.VaultRepo do
  @moduledoc """
  Provides vault-scoped database access.

  Wraps `Aurum.Repo` operations to ensure they run against
  the correct per-vault SQLite database.

  In test mode (`:test` env), uses the shared sandbox repo instead
  of spinning up per-vault databases.
  """

  alias Aurum.Repo
  alias Aurum.VaultDatabase.Manager

  @doc """
  Execute a function with the correct dynamic repo for the given vault.

  This ensures all Repo operations within the function use the vault's
  SQLite database, not the default/shared one.

  In test mode, this is a no-op that just executes the function.

  ## Example

      VaultRepo.with_vault(vault_id, fn ->
        Portfolio.create_item(attrs)
      end)
  """
  @spec with_vault(String.t(), (-> result)) :: result when result: var
  def with_vault(vault_id, fun) when is_binary(vault_id) and is_function(fun, 0) do
    if test_mode?() do
      # In test mode, use the shared sandbox repo
      fun.()
    else
      # Get or start the repo for this vault
      {:ok, _pid} = ensure_repo_started(vault_id)

      # Set the dynamic repo for this process
      Repo.put_dynamic_repo(repo_name(vault_id))

      # Execute the function
      fun.()
    end
  end

  @doc """
  Ensures the repo process for a vault is started.

  Returns `{:ok, pid}` if the repo is running or was started successfully.
  In test mode, returns the existing shared Repo pid.
  """
  @spec ensure_repo_started(String.t()) :: {:ok, pid()} | {:error, term()}
  def ensure_repo_started(vault_id) do
    if test_mode?() do
      # In test mode, return the shared sandbox repo
      {:ok, Process.whereis(Repo) || self()}
    else
      name = repo_name(vault_id)

      case Process.whereis(name) do
        nil -> start_repo(vault_id)
        pid -> {:ok, pid}
      end
    end
  end

  @doc """
  Returns the registered name for a vault's repo process.
  """
  @spec repo_name(String.t()) :: atom()
  def repo_name(vault_id) do
    :"aurum_vault_repo_#{vault_id}"
  end

  defp start_repo(vault_id) do
    db_path = Manager.vault_path(vault_id)

    unless File.exists?(db_path) do
      {:ok, _} = Manager.create_vault_database(vault_id)
    end

    opts = [
      name: repo_name(vault_id),
      database: db_path,
      pool_size: 1,
      journal_mode: :wal,
      busy_timeout: 5000
    ]

    case Repo.start_link(opts) do
      {:ok, pid} ->
        # Run migrations on this vault's database
        run_migrations(vault_id)
        {:ok, pid}

      {:error, {:already_started, pid}} ->
        {:ok, pid}

      error ->
        error
    end
  end

  defp run_migrations(vault_id) do
    # Set dynamic repo before running migrations
    Repo.put_dynamic_repo(repo_name(vault_id))

    migrations_path = Application.app_dir(:aurum, "priv/repo/migrations")

    if File.dir?(migrations_path) do
      Ecto.Migrator.run(Repo, migrations_path, :up, all: true, log: false)
    end
  end

  defp test_mode? do
    Application.get_env(:aurum, :env) == :test
  end
end
