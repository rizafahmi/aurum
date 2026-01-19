defmodule AurumWeb.ItemLive.Show do
  use AurumWeb, :live_view

  alias Aurum.Portfolio
  alias Aurum.Portfolio.Item
  alias AurumWeb.Format

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    socket =
      assign(socket,
        item_id: id,
        item: nil,
        valuation: nil,
        page_title: "Loading...",
        show_confirm_dialog: false
      )

    if connected?(socket), do: send(self(), :load_item)

    {:ok, socket}
  end

  @impl true
  def handle_info(:load_item, socket) do
    case Portfolio.get_item(socket.assigns.item_id) do
      nil ->
        {:noreply,
         socket
         |> put_flash(:error, "Item not found")
         |> push_navigate(to: ~p"/items")}

      item ->
        {_item, valuation} = Portfolio.valuate_item(item)

        {:noreply,
         assign(socket,
           item: item,
           valuation: valuation,
           page_title: item.name
         )}
    end
  end

  @impl true
  def render(%{item: nil} = assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div class="vault-card p-8 text-center">
        <span class="text-gold-muted">LOADING</span>
        <span class="terminal-cursor ml-1"></span>
      </div>
    </Layouts.app>
    """
  end

  def render(assigns) do
    assigns = assign(assigns, :gain_loss_class, decimal_sign_class(assigns.valuation.gain_loss))

    ~H"""
    <Layouts.app flash={@flash}>
      <.page_header title={@item.name} subtitle="Asset Details" title_test_id="item-name">
        <:actions>
          <.link navigate={~p"/items/#{@item.id}/edit"} class="btn-terminal text-xs uppercase tracking-wide">
            Edit
          </.link>
          <button id="delete-item" phx-click="show_confirm" class="btn-terminal text-xs uppercase tracking-wide text-danger border-[#f87171]">
            Delete
          </button>
        </:actions>
      </.page_header>

      <div class="grid grid-cols-1 lg:grid-cols-2 gap-6">
        <div class="vault-card p-6">
          <h2 class="text-gold-muted text-xs uppercase tracking-wide mb-4">{">_"} Physical Properties</h2>
          <dl class="space-y-4">
            <div class="flex justify-between border-b border-gold-dim pb-2">
              <dt class="text-gold-muted text-sm">Category</dt>
              <dd data-test="category" class="text-gold">{Item.category_label(@item.category)}</dd>
            </div>
            <div class="flex justify-between border-b border-gold-dim pb-2">
              <dt class="text-gold-muted text-sm">Weight</dt>
              <dd data-test="weight" class="text-gold">{@item.weight} {Item.weight_unit_short(@item.weight_unit)}</dd>
            </div>
            <div class="flex justify-between border-b border-gold-dim pb-2">
              <dt class="text-gold-muted text-sm">Purity</dt>
              <dd data-test="purity" class="text-gold">{Item.purity_label(@item.purity)}</dd>
            </div>
            <div class="flex justify-between border-b border-gold-dim pb-2">
              <dt class="text-gold-muted text-sm">Quantity</dt>
              <dd data-test="quantity" class="text-gold">{@item.quantity}</dd>
            </div>
            <div class="flex justify-between">
              <dt class="text-gold-muted text-sm">Pure Gold</dt>
              <dd data-test="pure-gold-weight" class="text-gold font-bold">{@valuation.pure_gold_grams} g</dd>
            </div>
          </dl>
        </div>

        <div class="vault-card p-6">
          <h2 class="text-gold-muted text-xs uppercase tracking-wide mb-4">{">_"} Valuation</h2>
          <dl class="space-y-4">
            <div class="flex justify-between border-b border-gold-dim pb-2">
              <dt class="text-gold-muted text-sm">Purchase Price</dt>
              <dd data-test="purchase-price" class="text-gold">{Format.currency(@item.purchase_price)}</dd>
            </div>
            <div class="flex justify-between border-b border-gold-dim pb-2">
              <dt class="text-gold-muted text-sm">Purchase Date</dt>
              <dd data-test="purchase-date" class="text-gold">{@item.purchase_date}</dd>
            </div>
            <div class="flex justify-between border-b border-gold-dim pb-2">
              <dt class="text-gold-muted text-sm">Current Value</dt>
              <dd data-test="current-value" class="text-gold font-bold">{Format.currency(@valuation.current_value)}</dd>
            </div>
            <div class="flex justify-between">
              <dt class="text-gold-muted text-sm">Gain/Loss</dt>
              <dd data-test="gain-loss" class={["font-bold", @gain_loss_class || "text-gold"]}>
                {Format.currency(@valuation.gain_loss)}
              </dd>
            </div>
          </dl>
        </div>

        <div :if={@item.notes} class="vault-card p-6 lg:col-span-2">
          <h2 class="text-gold-muted text-xs uppercase tracking-wide mb-4">{">_"} Notes</h2>
          <p data-test="notes" class="text-gold text-sm">{@item.notes}</p>
        </div>
      </div>

      <.back_link to={~p"/items"} label="Back to Portfolio" />

      <div
        :if={@show_confirm_dialog}
        id="confirm-dialog"
        class="fixed inset-0 z-50 flex items-center justify-center"
        style="background: rgba(15, 23, 42, 0.9)"
      >
        <div class="vault-card-glow p-6 max-w-sm w-full mx-4">
          <h2 class="text-lg font-bold text-gold mb-4">
            <span class="text-danger">[!]</span> Confirm Delete
          </h2>
          <p class="text-gold-muted text-sm mb-6">
            Are you sure you want to delete <span class="text-gold font-bold">{@item.name}</span>?
            This action cannot be undone.
          </p>
          <div class="flex justify-end gap-3">
            <button
              id="cancel-delete"
              phx-click="cancel_delete"
              class="btn-terminal text-xs uppercase tracking-wide"
            >
              Cancel
            </button>
            <button
              id="confirm-delete"
              phx-click="confirm_delete"
              class="btn-terminal-primary text-xs uppercase tracking-wide"
              style="background: #f87171; border-color: #f87171;"
            >
              Confirm Delete
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

  defp decimal_sign_class(nil), do: nil

  defp decimal_sign_class(%Decimal{} = d) do
    case Decimal.compare(d, 0) do
      :gt -> "text-success"
      :lt -> "text-danger"
      :eq -> nil
    end
  end
end
