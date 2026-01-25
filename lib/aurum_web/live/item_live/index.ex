defmodule AurumWeb.ItemLive.Index do
  use AurumWeb, :live_view

  alias Aurum.Accounts
  alias Aurum.Portfolio
  alias Aurum.Portfolio.Item
  alias AurumWeb.Format

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket), do: send(self(), :load_data)

    {:ok,
     socket
     |> assign(items: [], show_recovery_email_prompt: false)
     |> assign_email_form(%{})}
  end

  defp assign_email_form(socket, params) do
    assign(socket, :email_form, to_form(params, as: :recovery_email))
  end

  @impl true
  def handle_info(:load_data, socket) do
    items = Portfolio.list_items_with_current_values()
    show_prompt = should_show_recovery_email_prompt?(socket.assigns.vault_id, items)
    {:noreply, assign(socket, items: items, show_recovery_email_prompt: show_prompt)}
  end

  defp should_show_recovery_email_prompt?(nil, _items), do: false
  defp should_show_recovery_email_prompt?(_vault_id, []), do: false
  defp should_show_recovery_email_prompt?(_vault_id, [_, _ | _]), do: false

  defp should_show_recovery_email_prompt?(vault_id, [_single_item]) do
    not recovery_email_prompt_dismissed?(vault_id)
  end

  defp recovery_email_prompt_dismissed?(vault_id) do
    case Accounts.get_vault(vault_id) do
      nil -> false
      vault -> vault.recovery_email_prompt_dismissed || vault.recovery_email != nil
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.page_header title="PORTFOLIO" subtitle="Gold Assets Inventory">
        <:actions>
          <.link
            navigate={~p"/items/new"}
            class="btn-terminal-primary text-xs uppercase tracking-wide"
          >
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
              <td class="text-right" data-test="current-value">
                {Format.currency(item.current_value)}
              </td>
            </tr>
          </tbody>
        </table>
      </div>

      <div
        :if={@show_recovery_email_prompt}
        id="recovery-email-prompt"
        class="fixed inset-0 bg-black/80 flex items-center justify-center z-50"
      >
        <div class="vault-card p-6 max-w-md w-full mx-4">
          <h3 class="text-gold text-lg font-bold mb-2">Protect Your Vault</h3>
          <p class="text-gold-muted mb-4">Add email to protect your vault?</p>

          <.form for={@email_form} id="recovery-email-form" phx-submit="save_recovery_email">
            <.input
              field={@email_form[:recovery_email]}
              type="email"
              label="Email"
              placeholder="you@example.com"
            />
            <div class="flex gap-3 mt-4">
              <.button type="submit" variant="primary">Add recovery email</.button>
              <button
                type="button"
                phx-click="dismiss_recovery_email_prompt"
                class="btn-terminal text-xs uppercase tracking-wide"
              >
                Not now
              </button>
            </div>
          </.form>
        </div>
      </div>
    </Layouts.app>
    """
  end

  @impl true
  def handle_event("dismiss_recovery_email_prompt", _params, socket) do
    Accounts.dismiss_recovery_email_prompt(socket.assigns.vault_id)
    {:noreply, assign(socket, show_recovery_email_prompt: false)}
  end

  @impl true
  def handle_event("save_recovery_email", %{"recovery_email" => params}, socket) do
    case Accounts.set_recovery_email(socket.assigns.vault_id, params["recovery_email"]) do
      {:ok, _vault} ->
        {:noreply,
         socket
         |> assign(show_recovery_email_prompt: false)
         |> put_flash(:info, "Recovery email added")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, :email_form, to_form(changeset, as: :recovery_email))}

      {:error, _} ->
        {:noreply, socket}
    end
  end
end
