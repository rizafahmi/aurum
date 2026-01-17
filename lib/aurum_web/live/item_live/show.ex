defmodule AurumWeb.ItemLive.Show do
  use AurumWeb, :live_view

  alias Aurum.Portfolio
  alias Aurum.Portfolio.Item

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    item = Portfolio.get_item!(id)
    {_item, valuation} = Portfolio.valuate_item(item)

    {:ok, assign(socket, item: item, valuation: valuation, page_title: item.name)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1>{@item.name}</h1>

      <dl class="grid grid-cols-2 gap-4 mt-6">
        <div>
          <dt class="text-sm text-gray-500">Category</dt>
          <dd data-test="category">{Item.category_label(@item.category)}</dd>
        </div>

        <div>
          <dt class="text-sm text-gray-500">Weight</dt>
          <dd data-test="weight">{@item.weight} {Item.weight_unit_short(@item.weight_unit)}</dd>
        </div>

        <div>
          <dt class="text-sm text-gray-500">Purity</dt>
          <dd data-test="purity">{Item.purity_label(@item.purity)}</dd>
        </div>

        <div>
          <dt class="text-sm text-gray-500">Quantity</dt>
          <dd data-test="quantity">{@item.quantity}</dd>
        </div>

        <div>
          <dt class="text-sm text-gray-500">Purchase Price</dt>
          <dd data-test="purchase-price">{Item.format_currency(@item.purchase_price)}</dd>
        </div>

        <div>
          <dt class="text-sm text-gray-500">Purchase Date</dt>
          <dd data-test="purchase-date">{@item.purchase_date}</dd>
        </div>

        <div :if={@item.notes} class="col-span-2">
          <dt class="text-sm text-gray-500">Notes</dt>
          <dd data-test="notes">{@item.notes}</dd>
        </div>

        <div>
          <dt class="text-sm text-gray-500">Pure Gold Weight</dt>
          <dd data-test="pure-gold-weight">{@valuation.pure_gold_grams} g</dd>
        </div>

        <div>
          <dt class="text-sm text-gray-500">Current Value</dt>
          <dd data-test="current-value">{Item.format_currency(@valuation.current_value)}</dd>
        </div>

        <div>
          <dt class="text-sm text-gray-500">Gain/Loss</dt>
          <dd data-test="gain-loss">{Item.format_currency(@valuation.gain_loss)}</dd>
        </div>
      </dl>

      <div class="mt-8 flex gap-4">
        <.link navigate={~p"/items/#{@item.id}/edit"} class="text-blue-600 hover:underline">
          Edit
        </.link>
        <button id="delete-item" phx-click="delete" class="text-red-600 hover:underline">
          Delete
        </button>
        <.link navigate={~p"/items"} class="text-gray-600 hover:underline">
          Back
        </.link>
      </div>
    </Layouts.app>
    """
  end
end
