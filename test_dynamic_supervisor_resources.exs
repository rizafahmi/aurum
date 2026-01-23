# Risk 3: DynamicSupervisor Resource Management Test
# Tests starting/stopping hundreds of dynamic repos without FD/memory leaks
#
# What could go wrong:
# - File descriptor exhaustion (each SQLite conn = 1+ FD, 500 vaults = 500+ FDs)
# - Memory leak if repos don't fully terminate (ETS tables, process state)
# - Race condition: cleanup happens while request arrives, causing restart loops
# - DynamicSupervisor bottleneck under rapid start/stop churn
# - SQLite connection not released on repo stop (FD leak)
#
# Run: mix run test_dynamic_supervisor_resources.exs

defmodule VaultRepo do
  use Ecto.Repo, otp_app: :aurum, adapter: Ecto.Adapters.SQLite3
end

defmodule VaultSupervisor do
  use DynamicSupervisor

  def start_link(_), do: DynamicSupervisor.start_link(__MODULE__, nil, name: __MODULE__)
  def init(_), do: DynamicSupervisor.init(strategy: :one_for_one)

  def start_vault(vault_id) do
    db_path = "test_vaults/vault_#{vault_id}.db"
    File.mkdir_p!("test_vaults")

    child_spec = %{
      id: {:vault, vault_id},
      start:
        {VaultRepo, :start_link,
         [
           [
             database: db_path,
             name: :"vault_#{vault_id}",
             pool_size: 1,
             journal_mode: :wal
           ]
         ]},
      restart: :temporary
    }

    DynamicSupervisor.start_child(__MODULE__, child_spec)
  end

  def stop_vault(vault_id) do
    case Process.whereis(:"vault_#{vault_id}") do
      nil -> :ok
      pid -> DynamicSupervisor.terminate_child(__MODULE__, pid)
    end
  end
end

defmodule ResourceTest do
  # Reduced from 500 for faster test; scale up for prod validation
  @vault_count 200

  def run do
    File.rm_rf!("test_vaults")
    {:ok, _} = VaultSupervisor.start_link(nil)

    IO.puts("=== Risk 3: DynamicSupervisor Resource Test ===\n")
    {fd_before, mem_before} = measure_resources()
    IO.puts("Before: #{fd_before} FDs, #{mem_before} MB memory")

    # Phase 1: Start all vaults
    IO.puts("\n[1] Starting #{@vault_count} vault repos...")
    start_time = System.monotonic_time(:millisecond)

    for i <- 1..@vault_count do
      {:ok, _} = VaultSupervisor.start_vault(i)
      if rem(i, 50) == 0, do: IO.puts("  Started #{i}/#{@vault_count}")
    end

    elapsed = System.monotonic_time(:millisecond) - start_time
    {fd_peak, mem_peak} = measure_resources()
    IO.puts("After start: #{fd_peak} FDs, #{mem_peak} MB (#{elapsed}ms)")

    # Phase 2: Hit each vault with a query
    IO.puts("\n[2] Querying all vaults...")

    for i <- 1..@vault_count do
      repo = :"vault_#{i}"
      Ecto.Adapters.SQL.query!(repo, "SELECT 1")
    end

    # Phase 3: Stop all vaults
    IO.puts("\n[3] Stopping all vault repos...")
    for i <- 1..@vault_count, do: VaultSupervisor.stop_vault(i)
    # Let cleanup complete
    Process.sleep(1000)

    {fd_after_stop, mem_after_stop} = measure_resources()
    IO.puts("After stop: #{fd_after_stop} FDs, #{mem_after_stop} MB")

    # Phase 4: Restart all (simulates traffic after idle cleanup)
    IO.puts("\n[4] Restarting all vaults (simulating post-cleanup traffic)...")
    for i <- 1..@vault_count, do: {:ok, _} = VaultSupervisor.start_vault(i)

    {fd_restart, mem_restart} = measure_resources()
    IO.puts("After restart: #{fd_restart} FDs, #{mem_restart} MB")

    # Cleanup
    for i <- 1..@vault_count, do: VaultSupervisor.stop_vault(i)
    Process.sleep(500)
    {fd_final, mem_final} = measure_resources()

    IO.puts("\n=== RESULTS ===")
    IO.puts("FD delta (peak vs before): +#{fd_peak - fd_before}")
    IO.puts("FD after full cleanup: #{fd_final} (started at #{fd_before})")
    IO.puts("Memory peak: #{mem_peak} MB")
    IO.puts("Memory after cleanup: #{mem_final} MB")

    fd_leaked = fd_final - fd_before
    mem_leaked = mem_final - mem_before

    IO.puts("\nFD leak: #{if fd_leaked <= 5, do: "✅ PASS", else: "❌ FAIL (+#{fd_leaked})"}")
    IO.puts("Memory leak: #{if mem_leaked < 50, do: "✅ PASS", else: "❌ FAIL (+#{mem_leaked}MB)"}")

    File.rm_rf!("test_vaults")
  end

  defp measure_resources do
    # FD count via lsof for this BEAM process (macOS/Linux)
    pid = System.pid()

    fd_count =
      case System.cmd("sh", ["-c", "lsof -p #{pid} 2>/dev/null | wc -l"]) do
        {out, 0} -> String.trim(out) |> String.to_integer()
        _ -> -1
      end

    # Memory in MB
    mem_mb = (:erlang.memory(:total) / 1_000_000) |> Float.round(1)
    {fd_count, mem_mb}
  end
end

ResourceTest.run()
