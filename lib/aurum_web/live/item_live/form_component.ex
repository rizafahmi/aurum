defmodule AurumWeb.ItemLive.FormComponent do
  @moduledoc """
  Shared form component for creating and editing gold items.
  Handles validation and save events internally.
  """
  use AurumWeb, :live_component

  alias Aurum.Portfolio
  alias Aurum.Portfolio.Item

  @impl true
  def update(%{item: item} = assigns, socket) do
    changeset = Portfolio.change_item(item)

    {:ok,
     socket
     |> assign(assigns)
     |> assign_form(changeset)}
  end

  defp assign_form(socket, changeset) do
    assign(socket, :form, to_form(changeset))
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div>
      <.form
        for={@form}
        id="item-form"
        phx-target={@myself}
        phx-change="validate"
        phx-submit="save"
      >
        <.input field={@form[:name]} type="text" label="Name" id="item-name" />

        <.input
          field={@form[:category]}
          type="select"
          label="Category"
          id="item-category"
          prompt="Select category"
          options={Item.category_options()}
        />

        <.input field={@form[:weight]} type="number" label="Weight" id="item-weight" step="any" />

        <.input
          field={@form[:weight_unit]}
          type="select"
          label="Weight unit"
          id="item-weight-unit"
          options={Item.weight_unit_options()}
        />

        <.input
          field={@form[:purity]}
          type="select"
          label="Purity"
          id="item-purity"
          prompt="Select purity"
          options={Item.purity_options()}
        />

        <.input
          field={@form[:custom_purity]}
          type="number"
          label="Custom purity"
          id="item-custom-purity"
          step="0.01"
          min="0.01"
          max="100"
          placeholder="Or enter custom %"
        />

        <.input field={@form[:quantity]} type="number" label="Quantity" id="item-quantity" />

        <.input
          field={@form[:purchase_price]}
          type="number"
          label="Purchase price"
          id="item-purchase-price"
          step="0.01"
        />

        <.input
          field={@form[:purchase_date]}
          type="date"
          label="Purchase date"
          id="item-purchase-date"
        />

        <.input field={@form[:notes]} type="textarea" label="Notes" id="item-notes" />

        <div class="mt-4 flex gap-4">
          <.button type="submit">Save</.button>
          <.link :if={@action == :edit} navigate={@return_to}>Cancel</.link>
        </div>
      </.form>
    </div>
    """
  end

  @impl true
  def handle_event("validate", %{"item" => item_params}, socket) do
    changeset =
      socket.assigns.item
      |> Portfolio.change_item(item_params)
      |> Map.put(:action, :validate)

    {:noreply, assign_form(socket, changeset)}
  end

  @impl true
  def handle_event("save", %{"item" => item_params}, socket) do
    save_item(socket, socket.assigns.action, item_params)
  end

  defp save_item(socket, :new, params) do
    case Portfolio.create_item(params) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Gold item created successfully")
         |> push_navigate(to: socket.assigns.return_to)}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end

  defp save_item(socket, :edit, params) do
    case Portfolio.update_item(socket.assigns.item, params) do
      {:ok, item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Gold item updated successfully")
         |> push_navigate(to: ~p"/items/#{item.id}")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign_form(socket, changeset)}
    end
  end
end
