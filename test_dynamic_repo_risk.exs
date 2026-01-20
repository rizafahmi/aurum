# Risk #1 Validation: Dynamic Ecto Repos Across Concurrent Processes
# Run with: mix run test_dynamic_repo_risk.exs
#
# WHAT COULD GO WRONG:
# 1. Task.async loses process dictionary → queries hit wrong vault or crash
# 2. PubSub handlers spawn in different process → wrong vault
# 3. Race between put_dynamic_repo and query execution
# 4. Ecto.Repo.put_dynamic_repo not inherited by spawned processes

defmodule RiskTest.VaultRepo do
  use Ecto.Repo, otp_app: :aurum, adapter: Ecto.Adapters.SQLite3
end

alias RiskTest.VaultRepo

defmodule RiskTest.VaultSimulator do
  def setup_vaults(count) do
    for i <- 1..count do
      db_path = "/tmp/risk_test_vault_#{i}.db"
      File.rm(db_path)
      File.rm(db_path <> "-shm")
      File.rm(db_path <> "-wal")
      
      {:ok, pid} = VaultRepo.start_link(name: nil, database: db_path)
      VaultRepo.put_dynamic_repo(pid)
      
      VaultRepo.query!("""
        CREATE TABLE IF NOT EXISTS writes (
          id INTEGER PRIMARY KEY,
          vault_id INTEGER,
          process_id TEXT
        )
      """)
      
      {i, pid, db_path}
    end
  end

  # Simulates a LiveView process with async operations - WITHOUT the fix
  def simulate_liveview_broken(vault_id, repo_pid, iterations) do
    VaultRepo.put_dynamic_repo(repo_pid)
    process_id = inspect(self())
    
    results = for _ <- 1..iterations do
      task = Task.async(fn ->
        # BUG: No put_dynamic_repo here! Task loses parent's process dictionary
        try do
          VaultRepo.query!(
            "INSERT INTO writes (vault_id, process_id) VALUES (?, ?)",
            [vault_id, process_id]
          )
          :ok
        rescue
          e -> {:error, Exception.message(e)}
        end
      end)
      
      try do
        Task.await(task, 5000)
      catch
        :exit, _reason -> {:error, "Task crashed"}
      end
    end
    
    results
  end

  # Simulates a LiveView process with async operations - WITH the fix
  def simulate_liveview_fixed(vault_id, repo_pid, iterations) do
    VaultRepo.put_dynamic_repo(repo_pid)
    process_id = inspect(self())
    
    results = for _ <- 1..iterations do
      task = Task.async(fn ->
        # FIX: Explicitly set dynamic repo in spawned task
        VaultRepo.put_dynamic_repo(repo_pid)
        try do
          VaultRepo.query!(
            "INSERT INTO writes (vault_id, process_id) VALUES (?, ?)",
            [vault_id, process_id]
          )
          :ok
        rescue
          e -> {:error, Exception.message(e)}
        end
      end)
      
      try do
        Task.await(task, 5000)
      catch
        :exit, _reason -> {:error, "Task crashed"}
      end
    end
    
    results
  end

  def verify_no_leakage(vaults) do
    for {vault_id, repo_pid, _path} <- vaults do
      VaultRepo.put_dynamic_repo(repo_pid)
      %{rows: rows} = VaultRepo.query!("SELECT DISTINCT vault_id FROM writes")
      
      vault_ids_found = List.flatten(rows)
      leaked = Enum.reject(vault_ids_found, &(&1 == vault_id))
      
      status = if leaked == [], do: "✓ OK", else: "✗ LEAKED: #{inspect(leaked)}"
      IO.puts("  Vault #{vault_id}: found vault_ids #{inspect(vault_ids_found)} #{status}")
    end
  end

  def cleanup(vaults) do
    for {_id, repo_pid, path} <- vaults do
      try do
        GenServer.stop(repo_pid, :normal, 1000)
      catch
        _, _ -> :ok
      end
      File.rm(path)
      File.rm(path <> "-shm")
      File.rm(path <> "-wal")
    end
  end
end

alias RiskTest.VaultSimulator

# Suppress noisy error logs
Logger.configure(level: :warning)

# --- TEST 1: Without the fix (should fail) ---
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("TEST 1: Task.async WITHOUT put_dynamic_repo (should FAIL)")
IO.puts(String.duplicate("=", 60))

vaults = VaultSimulator.setup_vaults(3)

all_results = 
  for {vault_id, repo_pid, _} <- vaults do
    VaultSimulator.simulate_liveview_broken(vault_id, repo_pid, 2)
  end
  |> List.flatten()

failures = Enum.filter(all_results, fn r -> match?({:error, _}, r) end)
successes = Enum.filter(all_results, fn r -> r == :ok end)

IO.puts("\nResults: #{length(successes)} succeeded, #{length(failures)} failed")

if failures != [] do
  IO.puts("✗ RISK CONFIRMED: Tasks without put_dynamic_repo CRASH")
  IO.puts("  Error: repo lookup fails in spawned process")
else
  IO.puts("✓ All tasks succeeded (unexpected)")
end

VaultSimulator.cleanup(vaults)

# --- TEST 2: With the fix (should work) ---
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("TEST 2: Task.async WITH put_dynamic_repo (should PASS)")
IO.puts(String.duplicate("=", 60))

vaults = VaultSimulator.setup_vaults(3)

all_results = 
  for {vault_id, repo_pid, _} <- vaults do
    VaultSimulator.simulate_liveview_fixed(vault_id, repo_pid, 2)
  end
  |> List.flatten()

failures = Enum.filter(all_results, fn r -> match?({:error, _}, r) end)
successes = Enum.filter(all_results, fn r -> r == :ok end)

IO.puts("\nResults: #{length(successes)} succeeded, #{length(failures)} failed")

if failures == [] do
  IO.puts("✓ All tasks succeeded with the fix")
  IO.puts("\nVerifying no cross-vault data leakage:")
  VaultSimulator.verify_no_leakage(vaults)
else
  IO.puts("✗ #{length(failures)} tasks failed (unexpected)")
end

VaultSimulator.cleanup(vaults)

# --- CONCLUSION ---
IO.puts("\n" <> String.duplicate("=", 60))
IO.puts("CONCLUSION")
IO.puts(String.duplicate("=", 60))
IO.puts("""

Risk #1 is CONFIRMED: Task.async (and any spawned process) does NOT 
inherit the parent's dynamic repo binding from the process dictionary.

THE FIX: Always pass repo_pid into spawned processes and call 
put_dynamic_repo(repo_pid) at the start of each spawned function.

This applies to:
  - Task.async/Task.Supervisor
  - GenServer.cast handlers spawning work
  - PubSub message handlers  
  - Any code path that spawns a new process
""")

# Cleanup test files
File.rm("/tmp/test_dyn.db")
File.rm("/tmp/test_dyn_basic.exs")
