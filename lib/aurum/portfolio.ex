defmodule Aurum.Portfolio do
  @moduledoc """
  Portfolio valuation and aggregation.
  """

  alias Aurum.Financial

  @doc """
  Calculate total portfolio value in troy ounces.
  """
  def total_value_troy_ounces(holdings, spot_price_usd_per_troy_ounce) do
    holdings
    |> Enum.reduce(Decimal.new("0"), fn holding, acc ->
      weight_troy_ounces = convert_weight_to_troy_ounces(holding.weight, holding.weight_unit)
      pure_weight = Financial.pure_gold_weight(weight_troy_ounces, holding.purity)
      holding_value = Decimal.mult(pure_weight, spot_price_usd_per_troy_ounce)
      Decimal.add(acc, holding_value)
    end)
  end

  @doc """
  Calculate total cost basis in troy ounces.
  """
  def total_cost_basis_troy_ounces(holdings) do
    holdings
    |> Enum.reduce(Decimal.new("0"), fn holding, acc ->
      Decimal.add(acc, holding.cost_basis)
    end)
  end

  @doc """
  Calculate portfolio ROI percentage.
  """
  def portfolio_roi(holdings, spot_price_usd_per_troy_ounce) do
    total_value = total_value_troy_ounces(holdings, spot_price_usd_per_troy_ounce)
    total_cost = total_cost_basis_troy_ounces(holdings)
    Financial.calculate_roi(total_value, total_cost)
  end

  @doc """
  Calculate weight breakdown by category.
  Returns %{coins: weight, bars: weight, rounds: weight} in troy ounces.
  """
  def weight_breakdown_troy_ounces(holdings) do
    holdings
    |> Enum.group_by(& &1.category/1)
    |> Enum.map(fn {category, category_holdings} ->
      total_weight = Enum.reduce(category_holdings, Decimal.new("0"), fn holding, acc ->
        weight_troy_ounces = convert_weight_to_troy_ounces(holding.weight, holding.weight_unit)
        pure_weight = Financial.pure_gold_weight(weight_troy_ounces, holding.purity)
        Decimal.add(acc, pure_weight)
      end)
      {String.to_atom(category), total_weight}
    end)
    |> Map.new()
  end

  @doc """
  Calculate total pure gold weight in troy ounces.
  """
  def total_pure_weight_troy_ounces(holdings) do
    holdings
    |> Enum.reduce(Decimal.new("0"), fn holding, acc ->
      weight_troy_ounces = convert_weight_to_troy_ounces(holding.weight, holding.weight_unit)
      pure_weight = Financial.pure_gold_weight(weight_troy_ounces, holding.purity)
      Decimal.add(acc, pure_weight)
    end)
  end

  defp convert_weight_to_troy_ounces(weight, "grams") do
    Financial.convert_weight(weight, :grams, :troy_ounces)
  end

  defp convert_weight_to_troy_ounces(weight, "troy_ounces") do
    weight
  end

  defp convert_weight_to_troy_ounces(_weight, _unit) do
    Decimal.new("0")
  end
end
