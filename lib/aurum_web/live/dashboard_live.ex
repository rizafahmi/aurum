defmodule AurumWeb.DashboardLive do
  use AurumWeb, :live_view

  alias Aurum.Gold.PriceCache
  alias Aurum.Portfolio
  alias AurumWeb.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: send(self(), :load_data)
    {:ok, assign(socket, items: [], summary: nil, price_info: nil, refresh_error: false)}
  end

  @impl true
  def handle_info(:load_data, socket) do
    price_info = fetch_price_info()
    spot_price = if price_info, do: price_info.price_per_gram, else: nil
    {items, summary} = Portfolio.dashboard_summary(spot_price)
    {:noreply, assign(socket, items: items, summary: summary, price_info: price_info)}
  end

  @impl true
  def handle_event("refresh_price", _params, socket) do
    case PriceCache.refresh() do
      {:ok, resp} ->
        {:noreply,
         assign(socket,
           price_info: to_price_info(resp),
           refresh_error: Map.get(resp, :refresh_failed, false)
         )}

      {:error, _} ->
        {:noreply, assign(socket, refresh_error: true)}
    end
  end

  defp fetch_price_info do
    case PriceCache.get_price() do
      {:ok, resp} -> to_price_info(resp)
      _ -> nil
    end
  end

  defp to_price_info(%{
         price_data: %{price_per_oz: oz, price_per_gram: gram, currency: currency},
         fetched_at: fetched_at,
         stale: stale
       }) do
    %{
      price_per_oz: oz,
      price_per_gram: gram,
      currency: currency,
      fetched_at: fetched_at,
      stale: stale
    }
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.page_header title="VAULT STATUS" subtitle="Portfolio Overview & Market Data" />

      <.price_display price_info={@price_info} refresh_error={@refresh_error} />

      <.empty_state
        :if={@items == []}
        id="empty-portfolio"
        message="NO ASSETS DETECTED"
        description="Initialize your portfolio by adding gold items"
        cta_text="+ ADD FIRST ITEM"
        cta_path={~p"/items/new"}
      />

      <div :if={@items != []} class="grid grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
        <.stat_card
          id="total-gold-weight"
          label="Pure Gold"
          value={"#{@summary.total_pure_gold_grams} g"}
          icon="◊"
        />
        <.stat_card
          id="total-invested"
          label="Invested"
          value={Format.currency(@summary.total_invested)}
          icon="$"
        />
        <.stat_card
          id="total-current-value"
          label="Current Value"
          value={Format.currency(@summary.total_current_value)}
          icon="≡"
        />
        <.stat_card
          id="gain-loss-amount"
          label="Gain/Loss"
          value={Format.currency(@summary.total_gain_loss)}
          subtitle_id="gain-loss-percent"
          subtitle={Format.percent(@summary.total_gain_loss_percent)}
          icon="Δ"
          gain_loss={@summary.total_gain_loss}
        />
      </div>
    </Layouts.app>
    """
  end

  attr :price_info, :map, default: nil
  attr :refresh_error, :boolean, default: false

  defp price_display(assigns) do
    ~H"""
    <div class="vault-card-glow p-6 mb-8">
      <div class="flex items-center justify-between">
        <div>
          <div class="text-gold-muted text-xs uppercase tracking-wide mb-1">
            {">_"} GOLD SPOT PRICE
          </div>
          <div :if={@price_info} id="gold-price" class="stat-value">
            {Format.price(@price_info.price_per_oz)} <span class="text-gold-muted text-sm">{@price_info.currency}/oz</span>
          </div>
          <div :if={!@price_info} id="gold-price" class="stat-value text-gold-muted">
            -- AWAITING DATA --
          </div>
        </div>
        <div class="flex items-center gap-6">
          <button
            id="refresh-price"
            phx-click="refresh_price"
            class="btn-terminal text-xs uppercase tracking-wide"
          >
            ↻ Refresh
          </button>
          <div class="text-right">
            <div :if={@price_info} id="price-last-updated" class="text-xs text-gold-muted">
              Updated: {Format.datetime(@price_info.fetched_at)}
            </div>
            <div
              :if={@price_info && @price_info.stale}
              id="stale-price-indicator"
              class="text-xs text-warning font-medium"
            >
              [!] STALE DATA
            </div>
            <div :if={@refresh_error} id="refresh-error" class="text-xs text-danger font-medium">
              [ERR] REFRESH FAILED
            </div>
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
  attr :icon, :string, default: "●"
  attr :gain_loss, :any, default: nil

  defp stat_card(assigns) do
    assigns = assign(assigns, :sign_class, decimal_sign_class(assigns.gain_loss))

    ~H"""
    <div class="vault-card p-4">
      <div class="flex items-center gap-2 mb-2">
        <span class="text-gold-muted">{@icon}</span>
        <span class="stat-label">{@label}</span>
      </div>
      <div id={@id} class={["stat-value", @sign_class]}>
        {@value}
      </div>
      <div :if={@subtitle} id={@subtitle_id} class={["text-sm mt-1", @sign_class || "text-gold-muted"]}>
        {@subtitle}
      </div>
    </div>
    """
  end

  defp decimal_sign_class(nil), do: nil

  defp decimal_sign_class(%Decimal{} = d) do
    case Decimal.compare(d, 0) do
      :gt -> "text-success"
      :lt -> "text-danger"
      :eq -> nil
    end
  end

  defp decimal_sign_class(n) when is_number(n) do
    cond do
      n > 0 -> "text-success"
      n < 0 -> "text-danger"
      true -> nil
    end
  end
end
