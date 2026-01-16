defmodule Aurum.Gold.ApiMonitor do
  @moduledoc """
  Monitors gold price API reliability over time.
  Logs response times, failures, and schema validation results to a JSON file.

  Usage:
    # Start monitoring (runs every 15 minutes for 24 hours)
    Aurum.Gold.ApiMonitor.start_monitoring()

    # Run a single check
    Aurum.Gold.ApiMonitor.check_once()

    # Generate summary report
    Aurum.Gold.ApiMonitor.generate_report()
  """

  alias Aurum.Gold.PriceClient

  @log_file "priv/api_monitor_log.json"
  @check_interval_ms 15 * 60 * 1000
  @duration_ms 24 * 60 * 60 * 1000

  @doc """
  Runs a single API check against all providers and logs results.
  """
  def check_once do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    results = %{
      timestamp: timestamp,
      nbp: check_provider(:nbp, &PriceClient.fetch_nbp/0),
      goldapi: check_provider(:goldapi, &PriceClient.fetch_goldapi/0),
      metalpriceapi: check_provider(:metalpriceapi, &PriceClient.fetch_metalpriceapi/0)
    }

    append_log(results)
    results
  end

  @doc """
  Starts monitoring APIs every 15 minutes for 24 hours.
  Runs in the current process (blocking).
  """
  def start_monitoring do
    IO.puts("Starting API monitoring for 24 hours...")
    IO.puts("Checking every 15 minutes...")
    IO.puts("Results will be logged to #{@log_file}")

    end_time = System.monotonic_time(:millisecond) + @duration_ms
    monitoring_loop(end_time)
  end

  @doc """
  Generates a summary report from collected data.
  """
  def generate_report do
    case read_logs() do
      {:ok, logs} ->
        report = %{
          total_checks: length(logs),
          period: get_period(logs),
          providers: %{
            nbp: provider_stats(logs, :nbp),
            goldapi: provider_stats(logs, :goldapi),
            metalpriceapi: provider_stats(logs, :metalpriceapi)
          }
        }

        IO.puts("\n=== API Reliability Report ===\n")
        IO.puts("Total checks: #{report.total_checks}")
        IO.puts("Period: #{report.period.start} to #{report.period.end}")
        IO.puts("")

        for {provider, stats} <- report.providers do
          IO.puts("#{provider}:")
          IO.puts("  Success rate: #{Float.round(stats.success_rate * 100, 1)}%")
          IO.puts("  Avg response time: #{stats.avg_response_time_ms}ms")
          IO.puts("  Failures: #{inspect(stats.failure_reasons)}")
          IO.puts("")
        end

        report

      {:error, reason} ->
        IO.puts("Error reading logs: #{inspect(reason)}")
        {:error, reason}
    end
  end

  defp monitoring_loop(end_time) do
    if System.monotonic_time(:millisecond) < end_time do
      results = check_once()
      IO.puts("[#{results.timestamp}] Check complete")

      for {provider, result} <- results, provider != :timestamp do
        status = if result.success, do: "✓", else: "✗"
        time = result[:response_time_ms] || "N/A"
        IO.puts("  #{provider}: #{status} (#{time}ms)")
      end

      Process.sleep(@check_interval_ms)
      monitoring_loop(end_time)
    else
      IO.puts("\nMonitoring complete!")
      generate_report()
    end
  end

  defp check_provider(_name, fetch_fn) do
    start_time = System.monotonic_time(:millisecond)

    case fetch_fn.() do
      {:ok, data} ->
        %{
          success: true,
          response_time_ms: data.response_time_ms,
          price_per_oz: Decimal.to_string(data.price_per_oz),
          currency: data.currency
        }

      {:error, reason} ->
        end_time = System.monotonic_time(:millisecond)

        %{
          success: false,
          response_time_ms: end_time - start_time,
          error: format_error(reason)
        }
    end
  end

  defp format_error(:missing_api_key), do: "missing_api_key"
  defp format_error(:timeout), do: "timeout"
  defp format_error(:network_error), do: "network_error"
  defp format_error(:invalid_response), do: "invalid_response"
  defp format_error(:unauthorized), do: "unauthorized"
  defp format_error(:rate_limited), do: "rate_limited"
  defp format_error({:http_error, code}), do: "http_#{code}"
  defp format_error(other), do: inspect(other)

  defp append_log(results) do
    ensure_log_dir()

    existing =
      case File.read(@log_file) do
        {:ok, content} -> Jason.decode!(content)
        {:error, :enoent} -> []
      end

    updated = existing ++ [results]
    File.write!(@log_file, Jason.encode!(updated, pretty: true))
  end

  defp read_logs do
    case File.read(@log_file) do
      {:ok, content} -> {:ok, Jason.decode!(content)}
      {:error, reason} -> {:error, reason}
    end
  end

  defp ensure_log_dir do
    dir = Path.dirname(@log_file)
    File.mkdir_p!(dir)
  end

  defp get_period([]), do: %{start: nil, end: nil}

  defp get_period(logs) do
    timestamps = Enum.map(logs, & &1["timestamp"])
    %{start: List.first(timestamps), end: List.last(timestamps)}
  end

  defp provider_stats(logs, provider) do
    provider_key = Atom.to_string(provider)
    results = Enum.map(logs, &Map.get(&1, provider_key, %{}))

    successful = Enum.filter(results, &(&1["success"] == true))
    failed = Enum.filter(results, &(&1["success"] == false))

    success_rate =
      case results do
        [] -> 0.0
        _ -> length(successful) / length(results)
      end

    avg_response_time =
      case successful do
        [] ->
          0

        _ ->
          total = Enum.sum(Enum.map(successful, &(&1["response_time_ms"] || 0)))
          round(total / length(successful))
      end

    failure_reasons =
      failed
      |> Enum.map(&(&1["error"] || "unknown"))
      |> Enum.frequencies()

    %{
      success_rate: success_rate,
      avg_response_time_ms: avg_response_time,
      total_success: length(successful),
      total_failed: length(failed),
      failure_reasons: failure_reasons
    }
  end
end
