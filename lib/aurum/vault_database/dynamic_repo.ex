defmodule Aurum.VaultDatabase.DynamicRepo do
  @moduledoc """
  GenServer wrapper for per-vault Ecto repos with idle timeout.

  Each vault gets its own DynamicRepo process that manages the underlying
  Ecto Repo connection. After a period of inactivity (default 30 minutes),
  the process terminates to conserve resources. The next request will
  transparently restart the process.
  """

  use GenServer

  alias Aurum.Env
  alias Aurum.Repo
  alias Aurum.VaultDatabase.Manager

  @default_idle_timeout :timer.minutes(30)

  defstruct [:vault_id, :repo_pid, :idle_timeout, :timer_ref]

  @doc """
  Starts a DynamicRepo process for the given vault.

  ## Options

    * `:idle_timeout` - Time in milliseconds before the repo stops due to inactivity.
      Defaults to 30 minutes.
  """
  def start_repo(vault_id, opts \\ []) do
    idle_timeout = Keyword.get(opts, :idle_timeout, @default_idle_timeout)

    GenServer.start_link(__MODULE__, %{vault_id: vault_id, idle_timeout: idle_timeout},
      name: via_tuple(vault_id)
    )
  end

  @doc """
  Ensures a DynamicRepo process is started for the vault.
  Returns the pid of the running process.
  Handles race conditions where multiple processes try to start the same repo.
  """
  def ensure_started(vault_id, opts \\ []) do
    case lookup(vault_id) do
      {:ok, pid} ->
        {:ok, pid}

      :error ->
        case start_repo(vault_id, opts) do
          {:ok, pid} -> {:ok, pid}
          {:error, {:already_started, pid}} -> {:ok, pid}
          other -> other
        end
    end
  end

  @doc """
  Execute a function with the correct dynamic repo for the given vault.
  Resets the idle timer on each call.
  """
  def with_repo(vault_id, fun) when is_function(fun, 0) do
    case ensure_started(vault_id) do
      {:ok, pid} ->
        GenServer.call(pid, {:with_repo, fun})

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc """
  Looks up a DynamicRepo process by vault_id.
  """
  def lookup(vault_id) do
    case Registry.lookup(Aurum.VaultDatabase.Registry, vault_id) do
      [{pid, _}] -> {:ok, pid}
      [] -> :error
    end
  end

  @doc """
  Returns the underlying Ecto repo pid for a vault.

  Ensures the DynamicRepo process is started and returns the pid that can be
  used with `Repo.put_dynamic_repo/1`. Also resets the idle timer.
  """
  def get_repo_pid(vault_id) do
    case ensure_started(vault_id) do
      {:ok, pid} -> GenServer.call(pid, :get_repo_pid)
      {:error, reason} -> {:error, reason}
    end
  end

  defp via_tuple(vault_id) do
    {:via, Registry, {Aurum.VaultDatabase.Registry, vault_id}}
  end

  # GenServer callbacks

  @impl true
  def init(%{vault_id: vault_id, idle_timeout: idle_timeout}) do
    db_path = Manager.vault_path(vault_id)

    unless File.exists?(db_path) do
      {:ok, _} = Manager.create_vault_database(vault_id)
    end

    repo_opts = repo_options(db_path)

    case Repo.start_link(repo_opts) do
      {:ok, repo_pid} ->
        run_migrations(repo_pid)
        timer_ref = schedule_idle_timeout(idle_timeout)

        state = %__MODULE__{
          vault_id: vault_id,
          repo_pid: repo_pid,
          idle_timeout: idle_timeout,
          timer_ref: timer_ref
        }

        {:ok, state}

      {:error, reason} ->
        {:stop, reason}
    end
  end

  defp repo_options(db_path) do
    base_opts = [
      name: nil,
      database: db_path,
      pool_size: 1,
      journal_mode: :wal,
      busy_timeout: 5000
    ]

    if Env.test?() do
      Keyword.put(base_opts, :pool, DBConnection.ConnectionPool)
    else
      base_opts
    end
  end

  @impl true
  def handle_call({:with_repo, fun}, _from, state) do
    state = reset_idle_timer(state)
    prev_repo = Repo.get_dynamic_repo()

    result =
      try do
        Repo.put_dynamic_repo(state.repo_pid)
        fun.()
      after
        Repo.put_dynamic_repo(prev_repo)
      end

    {:reply, result, state}
  end

  @impl true
  def handle_call(:get_repo_pid, _from, state) do
    state = reset_idle_timer(state)
    {:reply, {:ok, state.repo_pid}, state}
  end

  @impl true
  def handle_info(:idle_timeout, state) do
    {:stop, :normal, state}
  end

  @impl true
  def terminate(_reason, state) do
    if state.repo_pid && Process.alive?(state.repo_pid) do
      GenServer.stop(state.repo_pid)
    end

    :ok
  end

  defp run_migrations(repo_pid) do
    Repo.put_dynamic_repo(repo_pid)
    migrations_path = Application.app_dir(:aurum, "priv/repo/migrations")

    if File.dir?(migrations_path) do
      Ecto.Migrator.run(Repo, migrations_path, :up, all: true, log: false)
    end
  end

  defp schedule_idle_timeout(timeout) do
    Process.send_after(self(), :idle_timeout, timeout)
  end

  defp reset_idle_timer(state) do
    if state.timer_ref do
      Process.cancel_timer(state.timer_ref)
    end

    timer_ref = schedule_idle_timeout(state.idle_timeout)
    %{state | timer_ref: timer_ref}
  end
end
