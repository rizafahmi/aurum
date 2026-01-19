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
      <.page_header title="PORTFOLIO" subtitle="Gold Assets Inventory">
        <:actions>
          <.link navigate={~p"/items/new"} class="btn-terminal-primary text-xs uppercase tracking-wide">
            + Add Item
          </.link>
        </:actions>
      </.page_header>

      <.empty_state
        :if={@items == []}
        id="empty-items"
        message="NO ASSETS DETECTED"
        description="Add gold items to build your portfolio"
        cta_text="+ ADD FIRST ITEM"
        cta_path={~p"/items/new"}
      />

      <div :if={@items != []} class="vault-card overflow-hidden">
        <table id="items-list" class="table-terminal">
          <thead>
            <tr>
              <th>Name</th>
              <th>Category</th>
              <th>Weight</th>
              <th>Purity</th>
              <th>Qty</th>
              <th class="text-right">Purchase</th>
              <th class="text-right">Current</th>
            </tr>
          </thead>
          <tbody>
            <tr :for={item <- @items}>
              <td>
                <.link navigate={~p"/items/#{item.id}"} class="hover:text-gold">
                  {item.name}
                </.link>
              </td>
              <td class="text-gold-muted">{Item.category_label(item.category)}</td>
              <td>{item.weight} {Item.weight_unit_short(item.weight_unit)}</td>
              <td>{Item.purity_label(item.purity)}</td>
              <td>{item.quantity}</td>
              <td class="text-right">{Format.currency(item.purchase_price)}</td>
              <td class="text-right" data-test="current-value">{Format.currency(item.current_value)}</td>
            </tr>
          </tbody>
        </table>
      </div>
    </Layouts.app>
    """
  end
end
