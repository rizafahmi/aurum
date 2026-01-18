defmodule AurumWeb.DashboardLive do
  use AurumWeb, :live_view

  alias Aurum.Gold.PriceCache
  alias Aurum.Portfolio
  alias AurumWeb.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: send(self(), :load_data)
    {:ok, assign(socket, items: [], summary: nil, price_info: nil)}
  end

  @impl true
  def handle_info(:load_data, socket) do
    {items, summary} = Portfolio.dashboard_summary()
    price_info = fetch_price_info()
    {:noreply, assign(socket, items: items, summary: summary, price_info: price_info)}
  end

  defp fetch_price_info do
    case PriceCache.get_price() do
      {:ok,
       %{
         price_data: %{price_per_oz: oz, price_per_gram: gram, currency: currency},
         fetched_at: fetched_at,
         stale: stale
       }} ->
        %{
          price_per_oz: oz,
          price_per_gram: gram,
          currency: currency,
          fetched_at: fetched_at,
          stale: stale
        }

      _ ->
        nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 class="text-2xl font-bold mb-6">Aurum</h1>

      <.price_display price_info={@price_info} />

      <div :if={@items == []} id="empty-portfolio" class="text-center py-12">
        <p class="text-gray-500 mb-4">Your portfolio is empty</p>
        <.link navigate={~p"/items/new"} class="text-blue-600 hover:underline">
          Add your first gold item
        </.link>
      </div>

      <div :if={@items != []} class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        <.stat_card
          id="total-gold-weight"
          label="Total Pure Gold"
          value={"#{@summary.total_pure_gold_grams} g"}
        />
        <.stat_card
          id="total-invested"
          label="Total Invested"
          value={Format.currency(@summary.total_invested)}
        />
        <.stat_card
          id="total-current-value"
          label="Current Value"
          value={Format.currency(@summary.total_current_value)}
        />
        <.stat_card
          id="gain-loss-amount"
          label="Gain/Loss"
          value={Format.currency(@summary.total_gain_loss)}
          subtitle_id="gain-loss-percent"
          subtitle={Format.percent(@summary.total_gain_loss_percent)}
        />
      </div>
    </Layouts.app>
    """
  end

  attr :price_info, :map, default: nil

  defp price_display(assigns) do
    ~H"""
    <div class="mb-6 p-4 bg-base-200 rounded-lg">
      <div class="flex items-center justify-between">
        <div>
          <div class="text-sm text-gray-500">Gold Spot Price</div>
          <div :if={@price_info} id="gold-price" class="text-xl font-bold">
            {Format.price(@price_info.price_per_oz)} {@price_info.currency}/oz
          </div>
          <div :if={!@price_info} id="gold-price" class="text-xl font-bold text-gray-400">
            Price unavailable
          </div>
        </div>
        <div :if={@price_info} class="text-right">
          <div id="price-last-updated" class="text-xs text-gray-500">
            Last updated: {Format.datetime(@price_info.fetched_at)}
          </div>
          <div
            :if={@price_info.stale}
            id="stale-price-indicator"
            class="text-xs text-amber-600 font-medium"
          >
            ⚠ Price may be stale
          </div>
        </div>
      </div>
    </div>
    """
  end

  attr :id, :string, required: true
  attr :label, :string, required: true
  attr :value, :string, required: true
  attr :subtitle, :string, default: nil
  attr :subtitle_id, :string, default: nil

  defp stat_card(assigns) do
    ~H"""
    <div class="p-4 bg-base-200 rounded-lg">
      <div class="text-sm text-gray-500">{@label}</div>
      <div id={@id} class="text-xl font-bold">{@value}</div>
      <div :if={@subtitle} id={@subtitle_id} class="text-sm text-gray-500">{@subtitle}</div>
    </div>
    """
  end
end
