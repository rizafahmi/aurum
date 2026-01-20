# Risk 2: SQLite Concurrent Access Test
# Tests 5 processes hammering the same vault.db for 60 seconds
#
# What could go wrong:
# - SQLITE_BUSY errors if WAL mode not enabled or busy_timeout too low
# - DBConnection checkout timeouts with pool_size: 1 under load
# - WAL checkpoint failures corrupting data
# - Ecto.Repo crashes propagating to all writers
#
# Run: mix run test_sqlite_concurrent.exs

defmodule TestRepo do
  use Ecto.Repo, otp_app: :aurum, adapter: Ecto.Adapters.SQLite3
end

defmodule TestSchema do
  use Ecto.Schema

  schema "writes" do
    field :process_id, :integer
    field :counter, :integer
    field :timestamp, :utc_datetime_usec
  end
end

defmodule ConcurrentTest do
  def run do
    db_path = "test_concurrent_vault.db"
    File.rm(db_path)
    File.rm(db_path <> "-wal")
    File.rm(db_path <> "-shm")

    {:ok, _pid} = TestRepo.start_link(
      database: db_path,
      pool_size: 1,
      journal_mode: :wal,
      busy_timeout: 5000
    )

    TestRepo.query!("""
      CREATE TABLE writes (
        id INTEGER PRIMARY KEY,
        process_id INTEGER,
        counter INTEGER,
        timestamp TEXT
      )
    """)

    IO.puts("Starting 5 concurrent writers for 60 seconds...")
    IO.puts("pool_size: 1, WAL mode, busy_timeout: 5000ms\n")

    duration_ms = 60_000
    start_time = System.monotonic_time(:millisecond)

    tasks = for proc_id <- 1..5 do
      Task.async(fn -> write_loop(proc_id, start_time, duration_ms, 0, 0) end)
    end

    results = Task.await_many(tasks, :infinity)

    total_in_db = TestRepo.aggregate(TestSchema, :count)
    total_written = Enum.sum(for {_, c, _} <- results, do: c)
    total_errors = Enum.sum(for {_, _, e} <- results, do: e)

    IO.puts("\n=== RESULTS ===")
    for {proc_id, count, errs} <- results do
      IO.puts("Process #{proc_id}: #{count} writes, #{errs} errors")
    end

    IO.puts("\nTotal attempted writes: #{total_written}")
    IO.puts("Total errors: #{total_errors}")
    IO.puts("Rows in database: #{total_in_db}")
    IO.puts("Data integrity: #{if total_written == total_in_db, do: "✅ PASS", else: "❌ FAIL"}")
    IO.puts("Zero errors: #{if total_errors == 0, do: "✅ PASS", else: "❌ FAIL"}")

    TestRepo.stop()
    File.rm(db_path)
    File.rm(db_path <> "-wal")
    File.rm(db_path <> "-shm")
  end

  defp write_loop(proc_id, start_time, duration_ms, counter, errors) do
    elapsed = System.monotonic_time(:millisecond) - start_time
    if elapsed >= duration_ms do
      {proc_id, counter, errors}
    else
      result = try do
        TestRepo.insert!(%TestSchema{
          process_id: proc_id,
          counter: counter,
          timestamp: DateTime.utc_now()
        })
        :ok
      rescue
        e -> {:error, Exception.message(e)}
      end

      case result do
        :ok -> write_loop(proc_id, start_time, duration_ms, counter + 1, errors)
        {:error, msg} ->
          IO.puts("  [P#{proc_id}] Error: #{msg}")
          write_loop(proc_id, start_time, duration_ms, counter, errors + 1)
      end
    end
  end
end

ConcurrentTest.run()
