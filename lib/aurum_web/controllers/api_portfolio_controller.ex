defmodule AurumWeb.APIPortfolioController do
  use AurumWeb, :controller

  alias Aurum.Gold
  alias Aurum.Portfolio

  def index(conn, _params) do
    holdings = Gold.list_holdings()
    latest_price = Gold.latest_price()

    conn
    |> put_status(200)
    |> json(%{
      holdings: Enum.map(holdings, &serialize_holding/1),
      latest_price: serialize_price(latest_price)
    })
  end

  def create(conn, %{"holding" => holding_params}) do
    case Gold.create_holding(holding_params) do
      {:ok, holding} ->
        conn
        |> put_status(201)
        |> json(%{holding: serialize_holding(holding)})

      {:error, changeset} ->
        conn
        |> put_status(422)
        |> json(%{errors: format_errors(changeset)})
    end
  end

  def show(conn, %{"id" => id}) do
    holding = Gold.get_holding!(id)

    conn
    |> put_status(200)
    |> json(%{holding: serialize_holding(holding)})
  rescue
    Ecto.NoResultsError ->
      conn
      |> put_status(404)
      |> json(%{error: "Holding not found"})
  end

  def update(conn, %{"id" => id, "holding" => holding_params}) do
    holding =
      try do
        Gold.get_holding!(id)
      rescue
        Ecto.NoResultsError -> nil
      end

    case holding do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "Holding not found"})

      holding ->
        case Gold.update_holding(holding, holding_params) do
          {:ok, updated_holding} ->
            conn
            |> put_status(200)
            |> json(%{holding: serialize_holding(updated_holding)})

          {:error, changeset} ->
            conn
            |> put_status(422)
            |> json(%{errors: format_errors(changeset)})
        end
    end
  end

  def delete(conn, %{"id" => id}) do
    holding =
      try do
        Gold.get_holding!(id)
      rescue
        Ecto.NoResultsError -> nil
      end

    case holding do
      nil ->
        conn
        |> put_status(404)
        |> json(%{error: "Holding not found"})

      holding ->
        case Gold.delete_holding(holding) do
          {:ok, _} ->
            conn
            |> put_status(200)
            |> json(%{success: true})

          {:error, _} ->
            conn
            |> put_status(500)
            |> json(%{error: "Failed to delete holding"})
        end
    end
  end

  def metrics(conn, _params) do
    holdings = Gold.list_holdings()
    latest_price = Gold.latest_price()

    price = case latest_price do
      nil -> %{usd: Decimal.new("0"), idr: Decimal.new("0")}
      price -> %{usd: price.spot_price_usd, idr: price.spot_price_idr}
    end

    metrics = %{
      total_value_usd: Portfolio.total_value_troy_ounces(holdings, price.usd),
      total_cost_basis_usd: Portfolio.total_cost_basis_troy_ounces(holdings),
      roi: Portfolio.portfolio_roi(holdings, price.usd),
      total_pure_weight: Portfolio.total_pure_weight_troy_ounces(holdings),
      weight_breakdown: Portfolio.weight_breakdown_troy_ounces(holdings)
    }

    conn
    |> put_status(200)
    |> json(%{metrics: serialize_metrics(metrics)})
  end

  defp serialize_holding(holding) do
    %{
      id: holding.id,
      name: holding.name,
      category: holding.category,
      weight: Decimal.to_string(holding.weight),
      weight_unit: holding.weight_unit,
      purity: Decimal.to_string(holding.purity),
      quantity: holding.quantity,
      cost_basis: Decimal.to_string(holding.cost_basis),
      purchase_date: holding.purchase_date,
      notes: holding.notes
    }
  end

  defp serialize_price(price) do
    case price do
      nil -> nil
      price -> %{
        id: price.id,
        currency: price.currency,
        spot_price_usd: Decimal.to_string(price.spot_price_usd),
        spot_price_idr: Decimal.to_string(price.spot_price_idr),
        exchange_rate: Decimal.to_string(price.exchange_rate),
        fetched_at: price.fetched_at
      }
    end
  end

  defp serialize_metrics(metrics) do
    %{
      total_value_usd: Decimal.to_string(metrics.total_value_usd),
      total_cost_basis_usd: Decimal.to_string(metrics.total_cost_basis_usd),
      roi: Decimal.to_string(metrics.roi),
      total_pure_weight: Decimal.to_string(metrics.total_pure_weight),
      weight_breakdown: %{
        coin: Decimal.to_string(Map.get(metrics.weight_breakdown, :coin, Decimal.new("0"))),
        bar: Decimal.to_string(Map.get(metrics.weight_breakdown, :bar, Decimal.new("0"))),
        round: Decimal.to_string(Map.get(metrics.weight_breakdown, :round, Decimal.new("0")))
      }
    }
  end

  defp format_errors(changeset) do
    # Ecto.Changeset.traverse_errors/2 returns a map of %{field => [messages]}
    changeset
    |> Ecto.Changeset.traverse_errors(fn {field, {msg, _opts}} ->
      {to_string(field), msg}
    end)
  rescue
    _ ->
      # Handle alternative error format - return simple map
      %{"error" => "Validation failed"}
  end
end
