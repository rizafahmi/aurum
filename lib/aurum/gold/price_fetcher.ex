defmodule Aurum.Gold.PriceFetcher do
  @moduledoc """
  Background GenServer that fetches gold prices periodically and broadcasts updates via PubSub.
  """

  use GenServer
  require Logger

  @fetch_interval 30 * 60 * 1000  # 30 minutes

  # Client API

  def start_link(_) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  def fetch_prices_now do
    GenServer.cast(__MODULE__, :fetch_prices)
  end

  # Server Callbacks

  @impl true
  def init(_) do
    # Schedule first fetch
    schedule_next_fetch()

    {:ok, %{last_price: nil, last_updated: nil}}
  end

  @impl true
  def handle_cast(:fetch_prices, state) do
    do_fetch_prices()
    {:noreply, state}
  end

  @impl true
  def handle_info(:fetch_prices, state) do
    do_fetch_prices()
    schedule_next_fetch()
    {:noreply, state}
  end

  # Private Functions

  defp do_fetch_prices do
    gold_price_usd = fetch_gold_price()
    exchange_rate = fetch_exchange_rate()

    gold_price_idr = convert_to_idr(gold_price_usd, exchange_rate)

    # Broadcast price update
    Phoenix.PubSub.broadcast(
      Aurum.PubSub,
      "price_updates",
      {:gold_price_idr, gold_price_idr, :gold_price_usd, gold_price_usd}
    )

    # Store price in database
    store_price_in_db(gold_price_idr, gold_price_usd, exchange_rate)

    Logger.info("Fetched gold price: USD #{Decimal.to_string(gold_price_usd)}, IDR #{Decimal.to_string(gold_price_idr)}")
  end

  defp fetch_gold_price do
    # In production, this would call Metals-API
    # For now, return a mock value
    Decimal.new("2350.50")
  end

  defp fetch_exchange_rate do
    # In production, this would call CurrencyLayer API
    # For now, return a mock value
    Decimal.new("15000")
  end

  defp convert_to_idr(gold_price_usd, exchange_rate) do
    Decimal.mult(gold_price_usd, exchange_rate)
  end

  defp store_price_in_db(gold_price_idr, gold_price_usd, exchange_rate) do
    %Aurum.Gold.Price{
      currency: "IDR",
      spot_price_usd: gold_price_usd,
      spot_price_idr: gold_price_idr,
      exchange_rate: exchange_rate,
      fetched_at: DateTime.truncate(DateTime.utc_now(), :second)
    }
    |> Aurum.Repo.insert()
  end

  defp schedule_next_fetch do
    Process.send_after(self(), :fetch_prices, @fetch_interval)
  end
end
