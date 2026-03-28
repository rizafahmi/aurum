defmodule Aurum.Financial do
  @moduledoc """
  Financial calculations for gold investment tracking.
  All calculations use Decimal for precision.
  """

  @troy_ounce_to_grams Decimal.new("31.1034768")
  @grams_to_troy_ounce Decimal.div(Decimal.new("1"), @troy_ounce_to_grams)

  def pure_gold_weight(weight, purity_decimal) do
    Decimal.mult(weight, purity_decimal)
  end

  def calculate_roi(current_value, cost_basis) do
    if Decimal.eq?(cost_basis, Decimal.new("0")) do
      Decimal.new("0")
    else
      gain = Decimal.sub(current_value, cost_basis)
      Decimal.mult(Decimal.div(gain, cost_basis), Decimal.new("100"))
    end
  end

  def convert_weight(weight, :grams, :troy_ounces) do
    Decimal.mult(weight, @grams_to_troy_ounce)
  end

  def convert_weight(weight, :troy_ounces, :grams) do
    Decimal.mult(weight, @troy_ounce_to_grams)
  end

  def karat_to_purity(24), do: Decimal.new("1.0")
  def karat_to_purity(22), do: Decimal.new("0.9167")
  def karat_to_purity(18), do: Decimal.new("0.75")
  def karat_to_purity(14), do: Decimal.new("0.5833")
  def karat_to_purity(karat) when is_integer(karat) and karat > 0 and karat <= 24 do
    Decimal.div(Decimal.new(karat), Decimal.new("24"))
  end
end
