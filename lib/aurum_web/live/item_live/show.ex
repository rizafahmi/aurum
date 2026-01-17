defmodule AurumWeb.ItemLive.Show do
  use AurumWeb, :live_view

  alias Aurum.Portfolio
  alias Aurum.Portfolio.Item

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    item = Portfolio.get_item!(id)
    {_item, valuation} = Portfolio.valuate_item(item)

    {:ok,
     assign(socket,
       item: item,
       valuation: valuation,
       page_title: item.name,
       show_confirm_dialog: false
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1 data-test="item-name">{@item.name}</h1>

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
        <button id="delete-item" phx-click="show_confirm" class="text-red-600 hover:underline">
          Delete
        </button>
        <.link navigate={~p"/items"} class="text-gray-600 hover:underline">
          Back
        </.link>
      </div>

      <div
        :if={@show_confirm_dialog}
        id="confirm-dialog"
        class="fixed inset-0 z-50 flex items-center justify-center bg-black/50"
      >
        <div class="bg-white rounded-lg p-6 max-w-sm w-full mx-4 shadow-xl">
          <h2 class="text-lg font-semibold mb-4">Confirm Delete</h2>
          <p class="mb-6">
            Are you sure you want to delete <strong>{@item.name}</strong>?
          </p>
          <div class="flex justify-end gap-3">
            <button
              id="cancel-delete"
              phx-click="cancel_delete"
              class="px-4 py-2 text-gray-600 hover:bg-gray-100 rounded"
            >
              Cancel
            </button>
            <button
              id="confirm-delete"
              phx-click="confirm_delete"
              class="px-4 py-2 bg-red-600 text-white rounded hover:bg-red-700"
            >
              Confirm
            </button>
          </div>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("show_confirm", _params, socket) do
    {:noreply, assign(socket, show_confirm_dialog: true)}
  end

  @impl true
  def handle_event("cancel_delete", _params, socket) do
    {:noreply, assign(socket, show_confirm_dialog: false)}
  end

  @impl true
  def handle_event("confirm_delete", _params, socket) do
    case Portfolio.delete_item(socket.assigns.item) do
      {:ok, _} ->
        {:noreply,
         socket
         |> put_flash(:info, "Gold item deleted")
         |> push_navigate(to: ~p"/items")}

      {:error, _reason} ->
        {:noreply,
         socket
         |> put_flash(:error, "Could not delete item")
         |> assign(show_confirm_dialog: false)}
    end
  end
end
