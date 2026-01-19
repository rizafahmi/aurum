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
      <.page_header title="EDIT ASSET" subtitle={@item.name} />

      <div class="vault-card p-6">
        <.live_component
          module={AurumWeb.ItemLive.FormComponent}
          id="edit-item-form"
          item={@item}
          action={:edit}
          return_to={~p"/items/#{@item.id}"}
        />
      </div>

      <.back_link to={~p"/items/#{@item.id}"} label="Back to Item" />
    </Layouts.app>
    """
  end
end
