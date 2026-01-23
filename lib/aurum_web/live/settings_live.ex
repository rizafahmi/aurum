defmodule AurumWeb.SettingsLive do
  use AurumWeb, :live_view

  @impl true
  def mount(_params, _session, socket) do
    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <Layouts.app flash={@flash}>
      <div id="settings-content">
        <div class="flex items-center justify-between mb-8">
          <div>
            <h1 class="text-2xl font-bold text-gold tracking-wide">
              <span class="text-gold-muted">[</span> SETTINGS <span class="text-gold-muted">]</span>
            </h1>
            <p class="text-gold-muted text-sm mt-1">Vault Configuration</p>
          </div>
        </div>

        <div class="vault-card p-6">
          <h2 class="text-gold text-lg mb-4">Data Export</h2>
          <p class="text-gold-muted text-sm mb-4">
            Download your vault database file. This SQLite file contains all your gold items and can be opened with standard database tools.
          </p>
          <.link href={~p"/settings/export"} class="btn-terminal-primary inline-block text-center">
            Export Database
          </.link>
        </div>
      </div>
    </Layouts.app>
    """
  end
end
