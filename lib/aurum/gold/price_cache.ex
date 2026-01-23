defmodule Aurum.Gold.PriceCache do
  @moduledoc """
  GenServer that caches gold prices with TTL-based staleness detection.

  Features:
  - Caches latest gold price from API
  - Tracks fetch timestamp for staleness detection
  - Returns cached price when API fails
  - Configurable staleness threshold (default: 15 minutes)

  Usage:
      # Get current price (fetches if cache empty or stale)
      {:ok, price_data} = PriceCache.get_price()

      # Check if cached price is stale
      PriceCache.stale?()

      # Force refresh from API
      PriceCache.refresh()

      # Get cache status
      PriceCache.status()
  """

  use GenServer

  alias Aurum.Gold.CachedPrice
  alias Aurum.Gold.PriceClient

  @stale_threshold_ms 15 * 60 * 1000
  @refresh_interval_ms 5 * 60 * 1000

  defstruct [:price_data, :fetched_at, :last_error, :fetch_count, :error_count]

  @type price_response :: %{
          required(:price_data) => map(),
          required(:stale) => boolean(),
          required(:age_ms) => non_neg_integer() | nil,
          required(:fetched_at) => DateTime.t() | nil,
          optional(:refresh_failed) => boolean()
        }

  # Client API

  @spec start_link(keyword()) :: GenServer.on_start()
  def start_link(opts \\ []) do
    name = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, opts, name: name)
  end

  @doc """
  Gets the current gold price. Fetches from API if cache is empty.
  Returns cached price even if stale, with staleness indicator.
  """
  @spec get_price(GenServer.server()) :: {:ok, price_response()} | {:error, term()}
  def get_price(server \\ __MODULE__) do
    GenServer.call(server, :get_price)
  end

  @doc """
  Returns true if the cached price is older than the staleness threshold.
  """
  @spec stale?(GenServer.server()) :: boolean()
  def stale?(server \\ __MODULE__) do
    GenServer.call(server, :stale?)
  end

  @doc """
  Forces a refresh from the API, updating the cache.
  """
  @spec refresh(GenServer.server()) :: {:ok, price_response()} | {:error, term()}
  def refresh(server \\ __MODULE__) do
    GenServer.call(server, :refresh, 15_000)
  end

  @doc """
  Returns the current cache status including staleness info.
  """
  @spec status(GenServer.server()) :: map()
  def status(server \\ __MODULE__) do
    GenServer.call(server, :status)
  end

  @doc """
  Returns the age of the cached price in milliseconds.
  Returns nil if no price is cached.
  """
  @spec age_ms(GenServer.server()) :: non_neg_integer() | nil
  def age_ms(server \\ __MODULE__) do
    GenServer.call(server, :age_ms)
  end

  @doc false
  @spec set_test_price(GenServer.server(), map(), DateTime.t()) :: :ok
  def set_test_price(server \\ __MODULE__, price_data, fetched_at) do
    GenServer.call(server, {:set_test_price, price_data, fetched_at})
  end

  @doc false
  @spec set_test_error(GenServer.server(), term()) :: :ok
  def set_test_error(server \\ __MODULE__, error) do
    GenServer.call(server, {:set_test_error, error})
  end

  # Server callbacks

  @impl true
  def init(opts) do
    stale_threshold = Keyword.get(opts, :stale_threshold_ms, @stale_threshold_ms)
    auto_refresh = Keyword.get(opts, :auto_refresh, true)
    price_client = Keyword.get(opts, :price_client, PriceClient)
    persist = Keyword.get(opts, :persist, true)

    {price_data, fetched_at} =
      if persist, do: load_from_database(), else: {nil, nil}

    state = %{
      cache: %__MODULE__{
        price_data: price_data,
        fetched_at: fetched_at,
        last_error: nil,
        fetch_count: 0,
        error_count: 0
      },
      stale_threshold_ms: stale_threshold,
      price_client: price_client,
      force_error: nil,
      persist: persist
    }

    if auto_refresh do
      schedule_refresh()
    end

    {:ok, state}
  end

  @impl true
  def handle_call(:get_price, _from, state) do
    cond do
      state.cache.price_data == nil ->
        {result, new_state} = do_fetch(state)
        {reply, final_state} = build_reply(result, new_state)
        {:reply, reply, final_state}

      stale_cache?(state) ->
        {result, new_state} = do_fetch(state)
        {reply, final_state} = build_reply(result, new_state)
        {:reply, reply, final_state}

      true ->
        reply = {:ok, build_price_response(state.cache.price_data, state)}
        {:reply, reply, state}
    end
  end

  @impl true
  def handle_call(:stale?, _from, state) do
    {:reply, stale_cache?(state), state}
  end

  @impl true
  def handle_call(:refresh, _from, state) do
    {result, new_state} = do_fetch(state)
    {reply, final_state} = build_reply(result, new_state)
    {:reply, reply, final_state}
  end

  @impl true
  def handle_call(:status, _from, state) do
    age = calculate_age(state)

    status = %{
      has_cached_price: state.cache.price_data != nil,
      stale: stale_cache?(state),
      age_ms: age,
      age_human: format_age(age),
      fetched_at: state.cache.fetched_at,
      fetch_count: state.cache.fetch_count,
      error_count: state.cache.error_count,
      last_error: state.cache.last_error,
      stale_threshold_ms: state.stale_threshold_ms
    }

    {:reply, status, state}
  end

  @impl true
  def handle_call(:age_ms, _from, state) do
    {:reply, calculate_age(state), state}
  end

  @impl true
  def handle_call({:set_test_price, price_data, fetched_at}, _from, state) do
    if state.persist do
      persist_to_database(price_data, fetched_at)
    end

    new_cache = %{
      state.cache
      | price_data: price_data,
        fetched_at: fetched_at,
        last_error: nil
    }

    {:reply, :ok, %{state | cache: new_cache}}
  end

  @impl true
  def handle_call({:set_test_error, error}, _from, state) do
    {:reply, :ok, %{state | force_error: error}}
  end

  @impl true
  def handle_info(:auto_refresh, state) do
    {_result, new_state} = do_fetch(state)
    schedule_refresh()
    {:noreply, new_state}
  end

  # Private functions

  defp do_fetch(%{force_error: error} = state) when error != nil do
    new_cache = %{
      state.cache
      | last_error: error,
        error_count: state.cache.error_count + 1
    }

    {{:error, error}, %{state | cache: new_cache, force_error: nil}}
  end

  defp do_fetch(state) do
    fetch_fn = get_fetch_function(state.price_client)

    case fetch_fn.() do
      {:ok, price_data} ->
        fetched_at = DateTime.utc_now()

        if state.persist do
          persist_to_database(price_data, fetched_at)
        end

        new_cache = %{
          state.cache
          | price_data: price_data,
            fetched_at: fetched_at,
            last_error: nil,
            fetch_count: state.cache.fetch_count + 1
        }

        {{:ok, price_data}, %{state | cache: new_cache}}

      {:error, reason} ->
        new_cache = %{
          state.cache
          | last_error: reason,
            error_count: state.cache.error_count + 1
        }

        {{:error, reason}, %{state | cache: new_cache}}
    end
  end

  defp get_fetch_function(price_client) when is_atom(price_client) do
    &price_client.fetch_with_fallback/0
  end

  defp get_fetch_function(price_client) when is_function(price_client, 0) do
    price_client
  end

  defp stale_cache?(state) do
    case state.cache.fetched_at do
      nil -> true
      fetched_at -> calculate_age_from_time(fetched_at) > state.stale_threshold_ms
    end
  end

  defp calculate_age(state) do
    case state.cache.fetched_at do
      nil -> nil
      fetched_at -> calculate_age_from_time(fetched_at)
    end
  end

  defp calculate_age_from_time(fetched_at) do
    DateTime.diff(DateTime.utc_now(), fetched_at, :millisecond)
  end

  defp build_price_response(price_data, state) do
    %{
      price_data: price_data,
      stale: stale_cache?(state),
      age_ms: calculate_age(state),
      fetched_at: state.cache.fetched_at
    }
  end

  defp build_reply({:ok, price_data}, state) do
    {{:ok, build_price_response(price_data, state)}, state}
  end

  defp build_reply({:error, reason}, state) do
    case state.cache.price_data do
      nil ->
        {{:error, reason}, state}

      price_data ->
        resp =
          build_price_response(price_data, state)
          |> Map.put(:refresh_failed, true)

        {{:ok, resp}, state}
    end
  end

  defp format_age(nil), do: "never"

  defp format_age(age_ms) when age_ms < 60_000 do
    "#{div(age_ms, 1000)} seconds ago"
  end

  defp format_age(age_ms) when age_ms < 3_600_000 do
    "#{div(age_ms, 60_000)} minutes ago"
  end

  defp format_age(age_ms) do
    "#{div(age_ms, 3_600_000)} hours ago"
  end

  defp schedule_refresh do
    Process.send_after(self(), :auto_refresh, @refresh_interval_ms)
  end

  defp load_from_database do
    case CachedPrice.get_latest() do
      nil -> {nil, nil}
      cached -> {CachedPrice.to_price_data(cached), cached.fetched_at}
    end
  end

  defp persist_to_database(price_data, fetched_at) do
    CachedPrice.save(price_data, fetched_at)
  end
end
