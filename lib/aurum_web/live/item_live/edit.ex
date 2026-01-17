defmodule AurumWeb.ItemLive.Edit do
  @moduledoc """
  LiveView for editing existing gold items.
  """
  use AurumWeb, :live_view

  alias Aurum.Portfolio

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    item = Portfolio.get_item!(id)

    {:ok,
     assign(socket,
       item: item,
       page_title: "Edit #{item.name}"
     )}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <h1>Edit {@item.name}</h1>

      <.live_component
        module={AurumWeb.ItemLive.FormComponent}
        id="edit-item-form"
        item={@item}
        action={:edit}
        return_to={~p"/items/#{@item.id}"}
      />
    </Layouts.app>
    """
  end
end
