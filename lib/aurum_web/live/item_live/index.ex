defmodule AurumWeb.ItemLive.Index do
  use AurumWeb, :live_view

  alias Aurum.Portfolio
  alias Aurum.Portfolio.Item

  def mount(_params, _session, socket) do
    items = Portfolio.list_items()
    {:ok, assign(socket, items: items)}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1>Gold Items</h1>

      <table>
        <thead>
          <tr>
            <th>Name</th>
            <th>Category</th>
            <th>Weight</th>
            <th>Purity</th>
            <th>Quantity</th>
            <th>Purchase Price</th>
          </tr>
        </thead>
        <tbody>
          <tr :for={item <- @items}>
            <td>{item.name}</td>
            <td>{Item.category_label(item.category)}</td>
            <td>{item.weight} {Item.weight_unit_short(item.weight_unit)}</td>
            <td>{Item.purity_label(item.purity)}</td>
            <td>{item.quantity}</td>
            <td>${item.purchase_price}</td>
          </tr>
        </tbody>
      </table>
    </Layouts.app>
    """
  end
end
