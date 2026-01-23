defmodule Aurum.DecimalUtils do
  @moduledoc """
  Centralized Decimal coercion utilities.
  """

  @spec to_decimal(Decimal.t() | number() | String.t() | nil) :: Decimal.t() | nil
  def to_decimal(nil), do: nil
  def to_decimal(%Decimal{} = d), do: d
  def to_decimal(n) when is_integer(n), do: Decimal.new(n)
  def to_decimal(n) when is_float(n), do: Decimal.from_float(n)
  def to_decimal(n) when is_binary(n), do: Decimal.new(n)
end
