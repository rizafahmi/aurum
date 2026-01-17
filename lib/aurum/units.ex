defmodule Aurum.Units do
  @moduledoc """
  Handles weight unit conversions with explicit, unambiguous functions.

  Design principles:
  - Store canonical value in grams (DB always stores grams)
  - Preserve original input unit for display
  - Explicit function names prevent accidental double-conversion
  - All conversions use Decimal for precision

  Conversion constant: 1 troy oz = 31.1035 grams (London fix standard)
  """

  @troy_oz_in_grams Decimal.new("31.1035")
  @weight_precision 4

  @type weight_unit :: :grams | :troy_oz
  @type weight_input :: %{
          value: Decimal.t(),
          unit: weight_unit(),
          canonical_grams: Decimal.t()
        }

  # Conversion functions with explicit naming

  @doc """
  Converts troy ounces to grams.

  ## Examples

      iex> Units.troy_oz_to_grams(1)
      Decimal.new("31.1035")

      iex> Units.troy_oz_to_grams(Decimal.new("2"))
      Decimal.new("62.2070")
  """
  @spec troy_oz_to_grams(Decimal.t() | number()) :: Decimal.t()
  def troy_oz_to_grams(troy_oz) do
    troy_oz
    |> to_decimal()
    |> Decimal.mult(@troy_oz_in_grams)
    |> round_weight()
  end

  @doc """
  Converts grams to troy ounces.

  ## Examples

      iex> Units.grams_to_troy_oz(31.1035)
      Decimal.new("1.0000")
  """
  @spec grams_to_troy_oz(Decimal.t() | number()) :: Decimal.t()
  def grams_to_troy_oz(grams) do
    grams
    |> to_decimal()
    |> Decimal.div(@troy_oz_in_grams)
    |> round_weight()
  end

  @doc """
  Converts any weight to canonical grams.
  Use this when storing to database.

  ## Examples

      iex> Units.to_canonical_grams(100, :grams)
      Decimal.new("100.0000")

      iex> Units.to_canonical_grams(1, :troy_oz)
      Decimal.new("31.1035")
  """
  @spec to_canonical_grams(Decimal.t() | number(), weight_unit()) :: Decimal.t()
  def to_canonical_grams(value, :grams) do
    value |> to_decimal() |> round_weight()
  end

  def to_canonical_grams(value, :troy_oz) do
    troy_oz_to_grams(value)
  end

  @doc """
  Converts canonical grams back to display unit.
  Use this when displaying to user in their preferred unit.

  ## Examples

      iex> Units.from_canonical_grams(Decimal.new("31.1035"), :troy_oz)
      Decimal.new("1.0000")

      iex> Units.from_canonical_grams(Decimal.new("100"), :grams)
      Decimal.new("100.0000")
  """
  @spec from_canonical_grams(Decimal.t(), weight_unit()) :: Decimal.t()
  def from_canonical_grams(grams, :grams) do
    grams |> round_weight()
  end

  def from_canonical_grams(grams, :troy_oz) do
    grams_to_troy_oz(grams)
  end

  @doc """
  Creates a weight input struct that preserves both original value/unit
  and canonical grams. Use this for form handling.

  ## Examples

      iex> Units.create_weight_input(1, :troy_oz)
      %{value: Decimal.new("1"), unit: :troy_oz, canonical_grams: Decimal.new("31.1035")}
  """
  @spec create_weight_input(Decimal.t() | number(), weight_unit()) :: weight_input()
  def create_weight_input(value, unit) do
    value_dec = to_decimal(value)
    canonical = to_canonical_grams(value_dec, unit)

    %{
      value: round_weight(value_dec),
      unit: unit,
      canonical_grams: canonical
    }
  end

  @doc """
  Recreates weight input from stored canonical grams and original unit.
  Use this when loading from database for editing.

  ## Examples

      iex> Units.restore_weight_input(Decimal.new("31.1035"), :troy_oz)
      %{value: Decimal.new("1.0000"), unit: :troy_oz, canonical_grams: Decimal.new("31.1035")}
  """
  @spec restore_weight_input(Decimal.t(), weight_unit()) :: weight_input()
  def restore_weight_input(canonical_grams, original_unit) do
    display_value = from_canonical_grams(canonical_grams, original_unit)

    %{
      value: display_value,
      unit: original_unit,
      canonical_grams: round_weight(canonical_grams)
    }
  end

  @doc """
  Updates weight input when user changes the value (same unit).
  Recalculates canonical grams.
  """
  @spec update_weight_value(weight_input(), Decimal.t() | number()) :: weight_input()
  def update_weight_value(weight_input, new_value) do
    create_weight_input(new_value, weight_input.unit)
  end

  @doc """
  Updates weight input when user changes the unit.
  Converts the current value to the new unit, preserving the physical amount.
  """
  @spec update_weight_unit(weight_input(), weight_unit()) :: weight_input()
  def update_weight_unit(weight_input, new_unit) do
    new_value = from_canonical_grams(weight_input.canonical_grams, new_unit)

    %{
      value: new_value,
      unit: new_unit,
      canonical_grams: weight_input.canonical_grams
    }
  end

  @doc """
  Validates that a weight value is positive.
  """
  @spec valid_weight?(Decimal.t() | number()) :: boolean()
  def valid_weight?(value) do
    dec = to_decimal(value)
    Decimal.gt?(dec, Decimal.new("0"))
  end

  @doc """
  Parses a weight unit from string input.
  """
  @spec parse_unit(String.t()) :: {:ok, weight_unit()} | {:error, :invalid_unit}
  def parse_unit("grams"), do: {:ok, :grams}
  def parse_unit("g"), do: {:ok, :grams}
  def parse_unit("troy_oz"), do: {:ok, :troy_oz}
  def parse_unit("oz"), do: {:ok, :troy_oz}
  def parse_unit("toz"), do: {:ok, :troy_oz}
  def parse_unit(_), do: {:error, :invalid_unit}

  @doc """
  Returns the display label for a unit.
  """
  @spec unit_label(weight_unit()) :: String.t()
  def unit_label(:grams), do: "g"
  def unit_label(:troy_oz), do: "oz"

  @doc """
  Returns the full name for a unit.
  """
  @spec unit_name(weight_unit()) :: String.t()
  def unit_name(:grams), do: "grams"
  def unit_name(:troy_oz), do: "troy ounces"

  @doc """
  Returns the conversion factor (how many grams in one unit).
  """
  @spec conversion_factor(weight_unit()) :: Decimal.t()
  def conversion_factor(:grams), do: Decimal.new("1")
  def conversion_factor(:troy_oz), do: @troy_oz_in_grams

  # Private helpers

  defp to_decimal(value), do: Aurum.DecimalUtils.to_decimal(value)

  defp round_weight(decimal) do
    Decimal.round(decimal, @weight_precision)
  end
end
