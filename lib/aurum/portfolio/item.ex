defmodule Aurum.Portfolio.Item do
  @moduledoc """
  Schema and helpers for gold portfolio items.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @categories [:bar, :coin, :jewelry, :other]
  @weight_units [:grams, :troy_oz]
  @purity_karats [24, 22, 18, 14]

  @type category :: :bar | :coin | :jewelry | :other
  @type weight_unit :: :grams | :troy_oz
  @type t :: %__MODULE__{
          id: integer() | nil,
          name: String.t() | nil,
          category: category() | nil,
          weight: Decimal.t() | nil,
          weight_unit: weight_unit() | nil,
          purity: integer() | nil,
          quantity: integer() | nil,
          purchase_price: Decimal.t() | nil,
          purchase_date: Date.t() | nil,
          notes: String.t() | nil,
          current_value: Decimal.t() | nil,
          custom_purity: Decimal.t() | nil,
          inserted_at: NaiveDateTime.t() | nil,
          updated_at: NaiveDateTime.t() | nil
        }

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
    field :custom_purity, :decimal, virtual: true

    timestamps()
  end

  @cast_fields ~w(name category weight weight_unit purity custom_purity quantity purchase_price purchase_date notes)a

  @spec changeset(t(), map()) :: Ecto.Changeset.t()
  def changeset(item, attrs) do
    item
    |> cast(attrs, @cast_fields)
    |> update_change(:name, &maybe_trim/1)
    |> update_change(:notes, &maybe_trim/1)
    |> validate_custom_purity()
    |> apply_custom_purity()
    |> validate_required([:name, :category, :weight, :weight_unit, :purity, :quantity, :purchase_price])
    |> validate_length(:name, min: 1, max: 100)
    |> validate_number(:weight, greater_than: 0)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:purchase_price, greater_than_or_equal_to: 0)
    |> validate_preset_purity()
    |> normalize_weight_to_grams()
  end

  @doc """
  Simplified changeset for quick add form with sensible defaults.
  Only requires: name, weight, purity, purchase_price.
  Defaults: category=:other, quantity=1, weight_unit=:grams, purchase_date=today.
  """
  @spec quick_changeset(t(), map()) :: Ecto.Changeset.t()
  def quick_changeset(item, attrs) do
    attrs_with_defaults =
      Map.merge(
        %{
          "category" => "other",
          "quantity" => "1",
          "weight_unit" => "grams",
          "purchase_date" => Date.utc_today() |> Date.to_string()
        },
        attrs
      )

    changeset(item, attrs_with_defaults)
  end

  defp validate_custom_purity(changeset) do
    case get_field(changeset, :custom_purity) do
      %Decimal{} -> validate_number(changeset, :custom_purity, greater_than: 0, less_than_or_equal_to: 100)
      _ -> changeset
    end
  end

  defp apply_custom_purity(changeset) do
    with %Decimal{} = custom <- get_field(changeset, :custom_purity),
         false <- Keyword.has_key?(changeset.errors, :custom_purity) do
      put_change(changeset, :purity, custom |> Decimal.round(0) |> Decimal.to_integer())
    else
      _ -> changeset
    end
  end

  defp validate_preset_purity(changeset) do
    case get_field(changeset, :custom_purity) do
      nil -> validate_inclusion(changeset, :purity, @purity_karats, message: "is invalid")
      _ -> changeset
    end
  end

  defp normalize_weight_to_grams(changeset) do
    weight = get_change(changeset, :weight)
    unit = get_change(changeset, :weight_unit) || get_field(changeset, :weight_unit)

    case {weight, unit} do
      {nil, _} -> changeset
      {_, :troy_oz} ->
        normalized = Aurum.Units.troy_oz_to_grams(weight)

        changeset
        |> put_change(:weight, normalized)
        |> put_change(:weight_unit, :grams)

      _ -> changeset
    end
  end

  defp maybe_trim(nil), do: nil

  defp maybe_trim(str) when is_binary(str) do
    case String.trim(str) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  @spec category_options() :: [{String.t(), category()}]
  def category_options do
    Enum.map(@categories, fn cat ->
      {category_label(cat), cat}
    end)
  end

  @spec weight_unit_options() :: [{String.t(), weight_unit()}]
  def weight_unit_options do
    Enum.map(@weight_units, fn unit ->
      {weight_unit_label(unit), unit}
    end)
  end

  @spec purity_options() :: [{String.t(), integer()}]
  def purity_options do
    Enum.map(@purity_karats, fn k ->
      {purity_label(k), k}
    end)
  end

  @spec category_label(category()) :: String.t()
  def category_label(:bar), do: "Bar"
  def category_label(:coin), do: "Coin"
  def category_label(:jewelry), do: "Jewelry"
  def category_label(:other), do: "Other"

  @spec weight_unit_label(weight_unit()) :: String.t()
  def weight_unit_label(:grams), do: "grams"
  def weight_unit_label(:troy_oz), do: "troy oz"

  @spec weight_unit_short(weight_unit()) :: String.t()
  defdelegate weight_unit_short(unit), to: Aurum.Units, as: :unit_label

  @spec purity_label(integer()) :: String.t()
  def purity_label(k), do: "#{k}K"
end
