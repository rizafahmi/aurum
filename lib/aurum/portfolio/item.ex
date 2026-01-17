defmodule Aurum.Portfolio.Item do
  @moduledoc """
  Schema and helpers for gold portfolio items.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @categories [:bar, :coin, :jewelry, :other]
  @weight_units [:grams, :troy_oz]
  @purity_karats [24, 22, 18, 14]

  schema "items" do
    field :name, :string
    field :category, Ecto.Enum, values: @categories
    field :weight, :decimal
    field :weight_unit, Ecto.Enum, values: @weight_units
    field :purity, :integer
    field :quantity, :integer
    field :purchase_price, :decimal
    field :purchase_date, :date
    field :notes, :string

    field :current_value, :decimal, virtual: true

    timestamps()
  end

  def changeset(item, attrs) do
    item
    |> cast(attrs, [:name, :category, :weight, :weight_unit, :purity, :quantity, :purchase_price, :purchase_date, :notes])
    |> update_change(:name, &maybe_trim/1)
    |> update_change(:notes, &maybe_trim/1)
    |> validate_required([:name, :category, :weight, :weight_unit, :purity, :quantity, :purchase_price])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_number(:weight, greater_than: 0)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:purchase_price, greater_than_or_equal_to: 0)
    |> validate_inclusion(:purity, @purity_karats)
  end

  defp maybe_trim(nil), do: nil

  defp maybe_trim(str) do
    trimmed = String.trim(str)
    if trimmed == "", do: nil, else: trimmed
  end

  def category_options do
    Enum.map(@categories, fn cat ->
      {category_label(cat), cat}
    end)
  end

  def weight_unit_options do
    Enum.map(@weight_units, fn unit ->
      {weight_unit_label(unit), unit}
    end)
  end

  def purity_options do
    Enum.map(@purity_karats, fn k ->
      {purity_label(k), k}
    end)
  end

  def category_label(:bar), do: "Bar"
  def category_label(:coin), do: "Coin"
  def category_label(:jewelry), do: "Jewelry"
  def category_label(:other), do: "Other"

  def weight_unit_label(:grams), do: "grams"
  def weight_unit_label(:troy_oz), do: "troy oz"

  def weight_unit_short(:grams), do: "g"
  def weight_unit_short(:troy_oz), do: "oz"

  def purity_label(k), do: "#{k}K"

  def format_currency(%Decimal{} = decimal) do
    decimal
    |> Decimal.round(2)
    |> Decimal.to_string(:normal)
    |> add_commas()
    |> then(&"$#{&1}")
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
      |> Enum.map(&Enum.join(&1, ""))
      |> Enum.join(",")
      |> String.reverse()

    sign <> int_with_commas <> "." <> frac
  end
end
