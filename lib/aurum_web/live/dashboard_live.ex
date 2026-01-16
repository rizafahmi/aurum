defmodule AurumWeb.DashboardLive do
  use AurumWeb, :live_view

  alias Aurum.Portfolio
  alias Aurum.Portfolio.Item

  @impl true
  def mount(_params, _session, socket) do
    socket =
      if connected?(socket) do
        {items, summary} = Portfolio.dashboard_summary()
        assign(socket, items: items, summary: summary)
      else
        assign(socket, items: [], summary: nil)
      end

    {:ok, socket}
  end

  @impl true
  def render(%{items: []} = assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 class="text-2xl font-bold mb-6">Aurum</h1>
      <div id="empty-portfolio" class="text-center py-12">
        <p class="text-gray-500 mb-4">Your portfolio is empty</p>
        <.link navigate="/items/new" class="text-blue-600 hover:underline">
          Add your first gold item
        </.link>
      </div>
    </Layouts.app>
    """
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 class="text-2xl font-bold mb-6">Aurum</h1>
      <div class="grid grid-cols-2 md:grid-cols-4 gap-4 mb-8">
        <.stat_card
          id="total-gold-weight"
          label="Total Pure Gold"
          value={"#{@summary.total_pure_gold_grams} g"}
        />
        <.stat_card
          id="total-invested"
          label="Total Invested"
          value={Item.format_currency(@summary.total_invested)}
        />
        <.stat_card
          id="total-current-value"
          label="Current Value"
          value={Item.format_currency(@summary.total_current_value)}
        />
        <.stat_card
          id="gain-loss-amount"
          label="Gain/Loss"
          value={Item.format_currency(@summary.total_gain_loss)}
          subtitle_id="gain-loss-percent"
          subtitle={"#{@summary.total_gain_loss_percent}%"}
        />
      </div>
    </Layouts.app>
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
