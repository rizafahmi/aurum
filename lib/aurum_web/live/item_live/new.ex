defmodule AurumWeb.ItemLive.New do
  @moduledoc """
  LiveView for creating new gold items.
  """
  use AurumWeb, :live_view

  alias Aurum.Portfolio.Item

  @impl true
  def mount(_params, _session, socket) do
    {:ok, assign(socket, page_title: "Add Gold Item")}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <.page_header title="NEW ASSET" subtitle="Register Gold Item" />

      <div class="vault-card p-6">
        <.live_component
          module={AurumWeb.ItemLive.FormComponent}
          id="new-item-form"
          item={%Item{}}
          action={:new}
          return_to={~p"/items"}
        />
      </div>

      <.back_link to={~p"/items"} label="Back to Portfolio" />
    </Layouts.app>
    """
  end
end
