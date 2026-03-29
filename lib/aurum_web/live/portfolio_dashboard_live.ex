defmodule AurumWeb.PortfolioDashboardLive do
  use AurumWeb, :live_view
  use AurumWeb, :html

  alias Aurum.Gold
  alias Aurum.Portfolio
  alias Aurum.Currency

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      Phoenix.PubSub.subscribe(Aurum.PubSub, "price_updates")
    end

    holdings = Gold.list_holdings()
    current_price = get_current_price()
    current_metrics = calculate_portfolio_metrics(holdings, current_price)

    socket =
      socket
      |> assign(:holdings, holdings)
      |> assign(:current_price, current_price)
      |> assign(:current_metrics, current_metrics)
      |> assign(:add_form, to_form(%{}))
      |> stream(:holdings, holdings)

    {:ok, socket}
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket) do
    Phoenix.PubSub.unsubscribe(Aurum.PubSub, "price_updates")
    {:noreply, socket}
  end

  @impl true
  def handle_info({:gold_price, %{idr: gold_price_idr, usd: gold_price_usd}}, socket) do
    new_price = %{idr: gold_price_idr, usd: gold_price_usd}
    holdings = socket.assigns.holdings
    new_metrics = calculate_portfolio_metrics(holdings, new_price)

    {:noreply,
     socket
     |> assign(:current_price, new_price)
     |> assign(:current_metrics, new_metrics)}
  end

  @impl true
  def handle_event("save", %{"holding" => holding_params}, socket) do
    case Gold.create_holding(holding_params) do
      {:ok, holding} ->
        new_holdings = [holding | socket.assigns.holdings]
        new_metrics = calculate_portfolio_metrics(new_holdings, socket.assigns.current_price)

        {:noreply,
         socket
         |> stream(:holdings, [holding])
         |> assign(:holdings, new_holdings)
         |> assign(:current_metrics, new_metrics)
         |> put_flash(:info, "Holding added successfully!")}

      {:error, changeset} ->
        {:noreply, assign(socket, :add_form, to_form(changeset))}
    end
  end

  @impl true
  def handle_event("validate", %{"holding" => holding_params}, socket) do
    changeset = Gold.change_holding(%Aurum.Gold.Holding{}, holding_params)
    {:noreply, assign(socket, :add_form, to_form(changeset))}
  end

  @impl true
  def handle_event("delete", %{"id" => id}, socket) do
    case Gold.get_holding(id) do
      {:ok, holding} ->
        {:ok, _} = Gold.delete_holding(holding)

        new_holdings = Enum.reject(socket.assigns.holdings, fn h -> h.id == holding.id end)
        new_metrics = calculate_portfolio_metrics(new_holdings, socket.assigns.current_price)

        {:noreply,
         socket
         |> stream_delete(:holdings, holding)
         |> assign(:holdings, new_holdings)
         |> assign(:current_metrics, new_metrics)
         |> put_flash(:info, "Holding deleted successfully!")}

      {:error, :not_found} ->
        {:noreply, put_flash(socket, :error, "Holding not found")}
    end
  end

  @impl true
  def handle_event("toggle_form", _params, socket) do
    {:noreply, socket}
  end

  defp get_current_price do
    case Gold.latest_price() do
      nil -> %{idr: Decimal.new("35257500"), usd: Decimal.new("2350.50")}
      price -> %{idr: price.spot_price_idr, usd: price.spot_price_usd}
    end
  end

  defp calculate_portfolio_metrics(holdings, current_price) do
    if Enum.empty?(holdings) do
      %{
        total_value_idr: Decimal.new("0"),
        total_cost_basis_idr: Decimal.new("0"),
        roi: Decimal.new("0"),
        total_pure_weight: Decimal.new("0"),
        weight_breakdown: %{
          coin: Decimal.new("0"),
          bar: Decimal.new("0"),
          round: Decimal.new("0")
        }
      }
    else
      total_value_usd = Portfolio.total_value_troy_ounces(holdings, current_price.usd)
      total_value_idr = Currency.usd_to_idr(total_value_usd)

      total_cost_basis_usd = Portfolio.total_cost_basis_troy_ounces(holdings)
      total_cost_basis_idr = Currency.usd_to_idr(total_cost_basis_usd)

      roi = Portfolio.portfolio_roi(holdings, current_price.usd)

      total_pure_weight = Portfolio.total_pure_weight_troy_ounces(holdings)

      weight_breakdown = Portfolio.weight_breakdown_troy_ounces(holdings)

      %{
        total_value_idr: total_value_idr,
        total_cost_basis_idr: total_cost_basis_idr,
        roi: roi,
        total_pure_weight: total_pure_weight,
        weight_breakdown: weight_breakdown
      }
    end
  end

  # Helper functions for template rendering
  defp format_large_number(decimal) do
    decimal
    |> Decimal.to_string()
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.map_join(".")
    |> String.reverse()
  end

  defp format_weight_unit("grams"), do: "g"
  defp format_weight_unit("troy_ounces"), do: "oz troy"
  defp format_weight_unit(_), do: ""

  defp get_category_icon("coin"), do: "hero-coin"
  defp get_category_icon("bar"), do: "hero-cube"
  defp get_category_icon("round"), do: "hero-circle-stack"
  defp get_category_icon(_), do: "hero-currency-dollar"
end
