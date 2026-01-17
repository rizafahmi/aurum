defmodule AurumWeb.ItemLive.Index do
  use AurumWeb, :live_view

  alias Aurum.Portfolio
  alias Aurum.Portfolio.Item
  alias AurumWeb.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: send(self(), :load_data)
    {:ok, assign(socket, items: [])}
  end

  @impl true
  def handle_info(:load_data, socket) do
    items = Portfolio.list_items_with_current_values()
    {:noreply, assign(socket, items: items)}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1>Gold Items</h1>

      <p :if={@items == []}>No items yet</p>

      <table :if={@items != []} id="items-list">
        <thead>
          <tr>
            <th>Name</th>
            <th>Category</th>
            <th>Weight</th>
            <th>Purity</th>
            <th>Quantity</th>
            <th>Purchase Price</th>
            <th>Current Value</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={item <- @items}>
            <td><.link navigate={~p"/items/#{item.id}"}>{item.name}</.link></td>
            <td>{Item.category_label(item.category)}</td>
            <td>{item.weight} {Item.weight_unit_short(item.weight_unit)}</td>
            <td>{Item.purity_label(item.purity)}</td>
            <td>{item.quantity}</td>
            <td>{Format.currency(item.purchase_price)}</td>
            <td data-test="current-value">{Format.currency(item.current_value)}</td>
          </tr>
        </tbody>
      </table>
    </Layouts.app>
    """
  end
end
