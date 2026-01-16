defmodule AurumWeb.ItemLive.New do
  use AurumWeb, :live_view

  alias Aurum.Portfolio
  alias Aurum.Portfolio.Item

  def mount(_params, _session, socket) do
    changeset = Portfolio.change_item(%Item{})
    {:ok, assign(socket, form: to_form(changeset))}
  end

  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1>Add Gold Item</h1>

      <.form for={@form} id="item-form" phx-change="validate" phx-submit="save">
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

        <.button type="submit">Save</.button>
      </.form>
    </Layouts.app>
    """
  end

  def handle_event("validate", %{"item" => item_params}, socket) do
    changeset =
      %Item{}
      |> Portfolio.change_item(item_params)
      |> Map.put(:action, :validate)

    {:noreply, assign(socket, form: to_form(changeset))}
  end

  def handle_event("save", %{"item" => item_params}, socket) do
    case Portfolio.create_item(item_params) do
      {:ok, _item} ->
        {:noreply,
         socket
         |> put_flash(:info, "Gold item created successfully")
         |> push_navigate(to: "/items")}

      {:error, %Ecto.Changeset{} = changeset} ->
        {:noreply, assign(socket, form: to_form(changeset))}
    end
  end
end
