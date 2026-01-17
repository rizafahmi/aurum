defmodule Aurum.Portfolio.Valuation do
  @moduledoc """
  Performs gold portfolio valuation calculations using Decimal for precision.

  All monetary values use 2 decimal places.
  All weight values use 4 decimal places.
  All intermediate calculations preserve full precision until final rounding.

  Formulas:
  - Pure gold weight = weight × (purity / 100) × quantity
  - Current value = pure gold weight × spot price per gram
  - Gain/loss = current value - purchase price
  - Gain/loss % = (gain/loss / purchase price) × 100
  """

  alias Aurum.Units

  @weight_precision 4
  @currency_precision 2
  @purity_precision 2

  @type weight_unit :: :grams | :troy_oz
  @type valuation_result :: %{
          pure_gold_grams: Decimal.t(),
          current_value: Decimal.t(),
          gain_loss: Decimal.t(),
          gain_loss_percent: Decimal.t() | nil
        }

  @doc """
  Calculates pure gold weight in grams.

  ## Parameters
  - weight: The weight value (Decimal or number)
  - weight_unit: :grams or :troy_oz
  - purity: Purity percentage (e.g., 99.9 for 24K, 91.67 for 22K)
  - quantity: Number of items

  ## Examples

      iex> Valuation.pure_gold_weight(10, :grams, 99.9, 1)
      Decimal.new("9.9900")

      iex> Valuation.pure_gold_weight(1, :troy_oz, 100, 1)
      Decimal.new("31.1035")
  """
  @spec pure_gold_weight(Decimal.t() | number(), weight_unit(), Decimal.t() | number(), integer()) ::
          Decimal.t()
  def pure_gold_weight(weight, weight_unit, purity, quantity) do
    weight_dec = to_decimal(weight)
    purity_dec = to_decimal(purity)
    quantity_dec = to_decimal(quantity)

    weight_in_grams = convert_to_grams(weight_dec, weight_unit)
    purity_factor = Decimal.div(purity_dec, Decimal.new("100"))

    weight_in_grams
    |> Decimal.mult(purity_factor)
    |> Decimal.mult(quantity_dec)
    |> round_weight()
  end

  @doc """
  Calculates the current value of gold holdings.

  ## Parameters
  - pure_gold_grams: Pure gold weight in grams
  - spot_price_per_gram: Current spot price per gram in USD

  ## Examples

      iex> Valuation.current_value(Decimal.new("31.1035"), Decimal.new("85.00"))
      Decimal.new("2643.80")
  """
  @spec current_value(Decimal.t(), Decimal.t()) :: Decimal.t()
  def current_value(pure_gold_grams, spot_price_per_gram) do
    pure_gold_grams
    |> Decimal.mult(spot_price_per_gram)
    |> round_currency()
  end

  @doc """
  Calculates gain or loss (current value - purchase price).
  """
  @spec gain_loss(Decimal.t(), Decimal.t()) :: Decimal.t()
  def gain_loss(current_value, purchase_price) do
    current_value
    |> Decimal.sub(purchase_price)
    |> round_currency()
  end

  @doc """
  Calculates gain/loss as a percentage of purchase price.
  Returns nil if purchase price is zero (to avoid division by zero).
  """
  @spec gain_loss_percent(Decimal.t(), Decimal.t() | number()) :: Decimal.t() | nil
  def gain_loss_percent(gain_loss_amount, purchase_price) do
    purchase_dec = to_decimal(purchase_price)

    if Decimal.eq?(purchase_dec, Decimal.new("0")) do
      nil
    else
      gain_loss_amount
      |> Decimal.div(purchase_dec)
      |> Decimal.mult(Decimal.new("100"))
      |> Decimal.round(@purity_precision)
    end
  end

  @doc """
  Performs full valuation for a single gold item.

  ## Parameters
  - weight: Weight value
  - weight_unit: :grams or :troy_oz
  - purity: Purity percentage
  - quantity: Number of items
  - purchase_price: Total purchase price
  - spot_price_per_gram: Current spot price per gram

  ## Returns
  Map with :pure_gold_grams, :current_value, :gain_loss, :gain_loss_percent
  """
  @spec valuate_item(
          weight :: Decimal.t() | number(),
          weight_unit :: weight_unit(),
          purity :: Decimal.t() | number(),
          quantity :: integer(),
          purchase_price :: Decimal.t() | number(),
          spot_price_per_gram :: Decimal.t() | number()
        ) :: valuation_result()
  def valuate_item(weight, weight_unit, purity, quantity, purchase_price, spot_price_per_gram) do
    pure_grams = pure_gold_weight(weight, weight_unit, purity, quantity)
    curr_value = current_value(pure_grams, to_decimal(spot_price_per_gram))
    purchase_dec = to_decimal(purchase_price) |> round_currency()
    gl = gain_loss(curr_value, purchase_dec)
    gl_percent = gain_loss_percent(gl, purchase_dec)

    %{
      pure_gold_grams: pure_grams,
      current_value: curr_value,
      gain_loss: gl,
      gain_loss_percent: gl_percent
    }
  end

  @doc """
  Aggregates valuations for multiple items into portfolio totals.
  """
  @spec aggregate_portfolio(list(valuation_result()), list(Decimal.t() | number())) :: %{
          total_pure_gold_grams: Decimal.t(),
          total_invested: Decimal.t(),
          total_current_value: Decimal.t(),
          total_gain_loss: Decimal.t(),
          total_gain_loss_percent: Decimal.t() | nil
        }
  def aggregate_portfolio(valuations, purchase_prices) do
    total_grams =
      valuations
      |> Enum.map(& &1.pure_gold_grams)
      |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)
      |> round_weight()

    total_value =
      valuations
      |> Enum.map(& &1.current_value)
      |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)
      |> round_currency()

    total_invested =
      purchase_prices
      |> Enum.map(&to_decimal/1)
      |> Enum.reduce(Decimal.new("0"), &Decimal.add/2)
      |> round_currency()

    total_gl = gain_loss(total_value, total_invested)
    total_gl_percent = gain_loss_percent(total_gl, total_invested)

    %{
      total_pure_gold_grams: total_grams,
      total_invested: total_invested,
      total_current_value: total_value,
      total_gain_loss: total_gl,
      total_gain_loss_percent: total_gl_percent
    }
  end

  @doc """
  Converts troy ounces to grams.
  Delegates to `Aurum.Units.troy_oz_to_grams/1`.
  """
  @spec troy_oz_to_grams(Decimal.t() | number()) :: Decimal.t()
  defdelegate troy_oz_to_grams(troy_oz), to: Units

  @doc """
  Converts grams to troy ounces.
  Delegates to `Aurum.Units.grams_to_troy_oz/1`.
  """
  @spec grams_to_troy_oz(Decimal.t() | number()) :: Decimal.t()
  defdelegate grams_to_troy_oz(grams), to: Units

  @doc """
  Returns the purity percentage for common karat values.
  """
  @spec karat_to_purity(integer()) :: Decimal.t()
  def karat_to_purity(24), do: Decimal.new("99.99")
  def karat_to_purity(22), do: Decimal.new("91.67")
  def karat_to_purity(18), do: Decimal.new("75.00")
  def karat_to_purity(14), do: Decimal.new("58.33")
  def karat_to_purity(10), do: Decimal.new("41.67")

  def karat_to_purity(karat) when is_integer(karat) and karat > 0 and karat <= 24 do
    Decimal.new(karat)
    |> Decimal.div(Decimal.new("24"))
    |> Decimal.mult(Decimal.new("100"))
    |> Decimal.round(@purity_precision)
  end

  # Private helpers

  defp convert_to_grams(weight, :grams), do: weight
  defp convert_to_grams(weight, :troy_oz), do: Units.troy_oz_to_grams(weight)

  defp to_decimal(value), do: Aurum.DecimalUtils.to_decimal(value)

  defp round_weight(decimal) do
    Decimal.round(decimal, @weight_precision)
  end

  defp round_currency(decimal) do
    Decimal.round(decimal, @currency_precision)
  end
end
