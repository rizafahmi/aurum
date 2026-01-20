defmodule AurumWeb.Format do
  @moduledoc """
  Presentation formatting helpers for templates and views.
  Centralizes all display formatting to avoid duplication across LiveViews.
  """

  @doc """
  Formats a Decimal as currency with Rp prefix and comma separators (Indonesian Rupiah).

  ## Examples

      iex> Format.currency(Decimal.new("1234.56"))
      "Rp1,234.56"
  """
  @spec currency(Decimal.t() | nil) :: String.t()
  def currency(nil), do: "—"

  def currency(%Decimal{} = decimal) do
    "Rp" <> (decimal |> decimal_to_2dp() |> add_commas())
  end

  @doc """
  Formats a Decimal as a price (rounds to 2 decimals).
  """
  @spec price(Decimal.t() | nil) :: String.t()
  def price(nil), do: "—"
  def price(%Decimal{} = decimal), do: decimal_to_2dp(decimal)

  defp decimal_to_2dp(%Decimal{} = decimal) do
    decimal |> Decimal.round(2) |> Decimal.to_string(:normal)
  end

  @doc """
  Formats a percentage value, returning nil for nil input.
  """
  @spec percent(Decimal.t() | nil) :: String.t() | nil
  def percent(nil), do: nil
  def percent(%Decimal{} = decimal), do: "#{Decimal.to_string(decimal)}%"

  @doc """
  Formats a DateTime in UTC format.
  """
  @spec datetime(DateTime.t() | nil) :: String.t()
  def datetime(nil), do: "Unknown"
  def datetime(%DateTime{} = dt), do: Calendar.strftime(dt, "%Y-%m-%d %H:%M UTC")

  @doc """
  Formats a weight with its unit abbreviation.
  """
  @spec weight(Decimal.t() | nil, Aurum.Units.weight_unit()) :: String.t()
  def weight(nil, _unit), do: "—"

  def weight(%Decimal{} = value, unit) do
    Decimal.to_string(value, :normal) <> " " <> Aurum.Units.unit_label(unit)
  end

  defp add_commas(str) do
    {sign, rest} =
      case str do
        "-" <> r -> {"-", r}
        r -> {"", r}
      end

    {int, frac} =
      case String.split(rest, ".", parts: 2) do
        [i, f] -> {i, String.pad_trailing(f, 2, "0")}
        [i] -> {i, "00"}
      end

    int_with_commas =
      int
      |> String.reverse()
      |> String.graphemes()
      |> Enum.chunk_every(3)
      |> Enum.map_join(",", &Enum.join(&1, ""))
      |> String.reverse()

    sign <> int_with_commas <> "." <> frac
  end
end
