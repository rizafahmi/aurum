defmodule Aurum.Gold.PriceCacheTest do
  use ExUnit.Case, async: true

  alias Aurum.Gold.PriceCache

  @moduletag :capture_log

  defp mock_price_data do
    %{
      price_per_oz: Decimal.new("2650.50"),
      price_per_gram: Decimal.new("85.21"),
      currency: "USD",
      timestamp: DateTime.utc_now(),
      source: :mock,
      response_time_ms: 100
    }
  end

  defp start_cache(opts) do
    name = :"test_cache_#{:erlang.unique_integer()}"
    opts = Keyword.merge([name: name, auto_refresh: false, persist: false], opts)
    {:ok, pid} = PriceCache.start_link(opts)
    {pid, name}
  end

  describe "basic caching" do
    test "returns error when cache is empty and fetch fails" do
      failing_client = fn -> {:error, :network_error} end
      {_pid, name} = start_cache(price_client: failing_client)

      assert {:error, :network_error} = PriceCache.get_price(name)
    end

    test "caches successful fetch result" do
      price_data = mock_price_data()
      mock_client = fn -> {:ok, price_data} end
      {_pid, name} = start_cache(price_client: mock_client)

      assert {:ok, result} = PriceCache.get_price(name)
      assert result.price_data.price_per_oz == price_data.price_per_oz
    end

    test "returns cached price on subsequent calls without refetching" do
      call_count = :counters.new(1, [:atomics])

      mock_client = fn ->
        :counters.add(call_count, 1, 1)
        {:ok, mock_price_data()}
      end

      {_pid, name} = start_cache(price_client: mock_client)

      {:ok, _} = PriceCache.get_price(name)
      {:ok, _} = PriceCache.get_price(name)
      {:ok, _} = PriceCache.get_price(name)

      assert :counters.get(call_count, 1) == 1
    end
  end

  describe "staleness detection" do
    test "new cache is considered stale" do
      mock_client = fn -> {:error, :skip} end
      {_pid, name} = start_cache(price_client: mock_client)

      assert PriceCache.stale?(name) == true
    end

    test "freshly fetched price is not stale" do
      mock_client = fn -> {:ok, mock_price_data()} end
      {_pid, name} = start_cache(price_client: mock_client)

      {:ok, _} = PriceCache.get_price(name)

      assert PriceCache.stale?(name) == false
    end

    test "price becomes stale after threshold" do
      mock_client = fn -> {:ok, mock_price_data()} end
      {_pid, name} = start_cache(price_client: mock_client, stale_threshold_ms: 50)

      {:ok, _} = PriceCache.get_price(name)
      assert PriceCache.stale?(name) == false

      Process.sleep(60)

      assert PriceCache.stale?(name) == true
    end

    test "stale indicator included in price response" do
      call_count = :counters.new(1, [:atomics])

      mock_client = fn ->
        :counters.add(call_count, 1, 1)

        if :counters.get(call_count, 1) == 1 do
          {:ok, mock_price_data()}
        else
          {:error, :api_unavailable}
        end
      end

      {_pid, name} = start_cache(price_client: mock_client, stale_threshold_ms: 50)

      {:ok, result1} = PriceCache.get_price(name)
      assert result1.stale == false

      Process.sleep(60)

      # When stale, get_price triggers refresh. If refresh fails, returns stale data with refresh_failed
      {:ok, result2} = PriceCache.get_price(name)
      assert result2.stale == true
      assert result2.refresh_failed == true
    end

    test "15 minute staleness threshold (simulated)" do
      mock_client = fn -> {:ok, mock_price_data()} end
      fifteen_minutes_ms = 15 * 60 * 1000

      {_pid, name} =
        start_cache(price_client: mock_client, stale_threshold_ms: fifteen_minutes_ms)

      {:ok, _} = PriceCache.get_price(name)

      status = PriceCache.status(name)
      assert status.stale_threshold_ms == fifteen_minutes_ms
      assert status.stale == false

      # Verify age tracking works
      assert status.age_ms != nil
      assert status.age_ms < 1000
    end
  end

  describe "API failure handling" do
    test "returns cached price when refresh fails" do
      call_count = :counters.new(1, [:atomics])

      mock_client = fn ->
        :counters.add(call_count, 1, 1)

        if :counters.get(call_count, 1) == 1 do
          {:ok, mock_price_data()}
        else
          {:error, :network_error}
        end
      end

      {_pid, name} = start_cache(price_client: mock_client)

      {:ok, first_result} = PriceCache.get_price(name)
      assert first_result.price_data != nil

      {:ok, refresh_result} = PriceCache.refresh(name)
      assert refresh_result.price_data != nil
      assert refresh_result.refresh_failed == true
    end

    test "tracks error count on failures" do
      call_count = :counters.new(1, [:atomics])

      mock_client = fn ->
        :counters.add(call_count, 1, 1)

        if :counters.get(call_count, 1) == 1 do
          {:ok, mock_price_data()}
        else
          {:error, :timeout}
        end
      end

      {_pid, name} = start_cache(price_client: mock_client)

      {:ok, _} = PriceCache.get_price(name)
      {:ok, _} = PriceCache.refresh(name)
      {:ok, _} = PriceCache.refresh(name)

      status = PriceCache.status(name)
      assert status.fetch_count == 1
      assert status.error_count == 2
      assert status.last_error == :timeout
    end

    test "continuous failures still return cached price" do
      call_count = :counters.new(1, [:atomics])

      mock_client = fn ->
        :counters.add(call_count, 1, 1)

        if :counters.get(call_count, 1) == 1 do
          {:ok, mock_price_data()}
        else
          {:error, :api_down}
        end
      end

      {_pid, name} = start_cache(price_client: mock_client)

      {:ok, initial} = PriceCache.get_price(name)

      for _ <- 1..5 do
        {:ok, result} = PriceCache.refresh(name)
        assert result.price_data.price_per_oz == initial.price_data.price_per_oz
        assert result.refresh_failed == true
      end

      status = PriceCache.status(name)
      assert status.error_count == 5
      assert status.has_cached_price == true
    end
  end

  describe "status reporting" do
    test "reports comprehensive status" do
      mock_client = fn -> {:ok, mock_price_data()} end
      {_pid, name} = start_cache(price_client: mock_client, stale_threshold_ms: 60_000)

      {:ok, _} = PriceCache.get_price(name)

      status = PriceCache.status(name)

      assert status.has_cached_price == true
      assert status.stale == false
      assert is_integer(status.age_ms)
      assert status.age_human =~ ~r/\d+ seconds ago/
      assert %DateTime{} = status.fetched_at
      assert status.fetch_count == 1
      assert status.error_count == 0
      assert status.last_error == nil
      assert status.stale_threshold_ms == 60_000
    end

    test "age_human formats correctly for different durations" do
      mock_client = fn -> {:ok, mock_price_data()} end
      {_pid, name} = start_cache(price_client: mock_client, stale_threshold_ms: 10)

      {:ok, _} = PriceCache.get_price(name)

      status1 = PriceCache.status(name)
      assert status1.age_human =~ ~r/\d+ seconds ago/

      Process.sleep(20)

      status2 = PriceCache.status(name)
      assert status2.stale == true
    end

    test "age_ms returns nil when no cached price" do
      mock_client = fn -> {:error, :skip} end
      {_pid, name} = start_cache(price_client: mock_client)

      assert PriceCache.age_ms(name) == nil
    end

    test "age_ms returns milliseconds since fetch" do
      mock_client = fn -> {:ok, mock_price_data()} end
      {_pid, name} = start_cache(price_client: mock_client)

      {:ok, _} = PriceCache.get_price(name)

      age1 = PriceCache.age_ms(name)
      assert is_integer(age1)
      assert age1 >= 0

      Process.sleep(50)

      age2 = PriceCache.age_ms(name)
      assert age2 > age1
    end
  end

  describe "refresh behavior" do
    test "refresh updates cached price" do
      call_count = :counters.new(1, [:atomics])

      mock_client = fn ->
        count = :counters.get(call_count, 1) + 1
        :counters.put(call_count, 1, count)

        {:ok,
         %{
           price_per_oz: Decimal.new(to_string(2000 + count * 100)),
           price_per_gram: Decimal.new("85.21"),
           currency: "USD",
           timestamp: DateTime.utc_now(),
           source: :mock,
           response_time_ms: 100
         }}
      end

      {_pid, name} = start_cache(price_client: mock_client)

      {:ok, result1} = PriceCache.get_price(name)
      assert Decimal.eq?(result1.price_data.price_per_oz, Decimal.new("2100"))

      {:ok, result2} = PriceCache.refresh(name)
      assert Decimal.eq?(result2.price_data.price_per_oz, Decimal.new("2200"))

      {:ok, result3} = PriceCache.get_price(name)
      assert Decimal.eq?(result3.price_data.price_per_oz, Decimal.new("2200"))
    end

    test "refresh resets staleness" do
      mock_client = fn -> {:ok, mock_price_data()} end
      {_pid, name} = start_cache(price_client: mock_client, stale_threshold_ms: 30)

      {:ok, _} = PriceCache.get_price(name)
      Process.sleep(40)
      assert PriceCache.stale?(name) == true

      {:ok, _} = PriceCache.refresh(name)
      assert PriceCache.stale?(name) == false
    end
  end

  describe "API rate limiting configuration" do
    @one_hour_ms 60 * 60 * 1000

    test "auto-refresh interval is at least 1 hour to prevent API quota exhaustion" do
      refresh_interval = get_module_attribute(:refresh_interval_ms)
      assert refresh_interval >= @one_hour_ms,
        "Refresh interval #{refresh_interval}ms is too aggressive. " <>
        "Must be at least 1 hour (#{@one_hour_ms}ms) to avoid exceeding API quotas."
    end

    test "stale threshold is at least 1 hour" do
      stale_threshold = get_module_attribute(:stale_threshold_ms)
      assert stale_threshold >= @one_hour_ms,
        "Stale threshold #{stale_threshold}ms is too short. " <>
        "Must be at least 1 hour (#{@one_hour_ms}ms) to reduce unnecessary API calls."
    end

    test "monthly API requests stay under 1000 with current refresh interval" do
      refresh_interval_ms = get_module_attribute(:refresh_interval_ms)
      requests_per_day = div(24 * 60 * 60 * 1000, refresh_interval_ms)
      requests_per_month = requests_per_day * 30

      assert requests_per_month < 1000,
        "Current refresh interval would cause ~#{requests_per_month} API requests/month. " <>
        "Most free API tiers allow only 100-500 requests/month."
    end

    defp get_module_attribute(attr) do
      {:ok, tokens} = File.read!("lib/aurum/gold/price_cache.ex")
                      |> Code.string_to_quoted()

      {_ast, value} = Macro.prewalk(tokens, nil, fn
        {:@, _, [{^attr, _, [value]}]} = node, _acc -> {node, value}
        node, acc -> {node, acc}
      end)

      {result, _} = Code.eval_quoted(value)
      result
    end
  end
end
