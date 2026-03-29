defmodule Aurum.Currency do
  @moduledoc """
  Currency conversion utilities.
  """

  @default_exchange_rate Decimal.new("15000")

  @doc """
  Convert USD amount to IDR using exchange rate.
  Rounds to nearest thousand for display.
  """
  def usd_to_idr(amount_usd, exchange_rate \\ @default_exchange_rate) do
    converted = Decimal.mult(amount_usd, exchange_rate)
    round_to_nearest_thousand(converted)
  end

  @doc """
  Round decimal to nearest thousand.
  """
  def round_to_nearest_thousand(amount, precision \\ -3) do
    Decimal.round(amount, precision, :half_up)
  end

  @doc """
  Format IDR value with thousand separators.
  """
  def format_idr(amount_idr) do
    amount_str = Decimal.to_string(amount_idr)
    add_thousand_separators(amount_str)
  end

  defp add_thousand_separators(""), do: "0"

  defp add_thousand_separators(str) do
    str
    |> String.reverse()
    |> String.graphemes()
    |> Enum.chunk_every(3)
    |> Enum.join(",")
    |> String.reverse()
  end
end
