defmodule AurumWeb.Layouts do
  @moduledoc """
  This module holds layouts and related functionality
  used by your application.
  """
  use AurumWeb, :html

  embed_templates "layouts/*"

  @doc """
  Renders your app layout.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  slot :inner_block, required: true

  def app(assigns) do
    ~H"""
    <header class="vault-card border-b border-gold-dim px-6 py-4">
      <div class="max-w-6xl mx-auto flex items-center justify-between">
        <.link navigate={~p"/"} class="flex items-center gap-3 group">
          <div class="w-8 h-8 border border-gold flex items-center justify-center">
            <span class="text-gold font-bold">Au</span>
          </div>
          <span class="text-gold font-bold tracking-wider">AURUM VAULT</span>
        </.link>
        <nav class="flex items-center gap-6">
          <.link
            navigate={~p"/"}
            class="text-gold-muted hover:text-gold text-sm uppercase tracking-wide"
          >
            Dashboard
          </.link>
          <.link
            navigate={~p"/items"}
            class="text-gold-muted hover:text-gold text-sm uppercase tracking-wide"
          >
            Portfolio
          </.link>
          <.link
            navigate={~p"/items/new"}
            class="btn-terminal-primary text-xs uppercase tracking-wide"
          >
            + Add Item
          </.link>
        </nav>
      </div>
    </header>

    <main class="px-6 py-8">
      <div class="max-w-6xl mx-auto">
        {render_slot(@inner_block)}
      </div>
    </main>

    <.flash_group flash={@flash} />
    """
  end

  @doc """
  Shows the flash group with standard titles and content.
  """
  attr :flash, :map, required: true, doc: "the map of flash messages"
  attr :id, :string, default: "flash-group", doc: "the optional id of flash container"

  def flash_group(assigns) do
    ~H"""
    <div id={@id} class="fixed top-4 right-4 z-50 space-y-2" aria-live="polite">
      <.flash kind={:info} flash={@flash} />
      <.flash kind={:error} flash={@flash} />

      <.flash
        id="client-error"
        kind={:error}
        title="Connection Lost"
        phx-disconnected={show(".phx-client-error #client-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#client-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Reconnecting<span class="terminal-cursor ml-1"></span>
      </.flash>

      <.flash
        id="server-error"
        kind={:error}
        title="System Error"
        phx-disconnected={show(".phx-server-error #server-error") |> JS.remove_attribute("hidden")}
        phx-connected={hide("#server-error") |> JS.set_attribute({"hidden", ""})}
        hidden
      >
        Reconnecting<span class="terminal-cursor ml-1"></span>
      </.flash>
    </div>
    """
  end
end
