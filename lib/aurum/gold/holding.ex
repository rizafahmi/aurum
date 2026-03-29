defmodule Aurum.Gold.Holding do
  @moduledoc """
  Schema for gold holdings.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "holdings" do
    field :name, :string
    field :category, :string
    field :weight, :decimal
    field :weight_unit, :string
    field :purity, :decimal
    field :quantity, :integer, default: 1
    field :cost_basis, :decimal
    field :purchase_date, :date
    field :notes, :string

    timestamps()
  end

  def categories do
    [:coin, :bar, :round]
  end

  def weight_units do
    [:grams, :troy_ounces]
  end

  def changeset(holding, attrs) do
    holding
    |> cast(attrs, [
      :name,
      :category,
      :weight,
      :weight_unit,
      :purity,
      :quantity,
      :cost_basis,
      :purchase_date,
      :notes
    ])
    |> validate_required([:name, :category, :weight, :weight_unit, :purity, :cost_basis])
    |> validate_number(:weight, greater_than: 0)
    |> validate_number(:purity, greater_than: 0, less_than_or_equal_to: 1)
    |> validate_number(:quantity, greater_than: 0)
    |> validate_number(:cost_basis, greater_than_or_equal_to: 0)
    |> validate_inclusion(:category, ["coin", "bar", "round"])
    |> validate_inclusion(:weight_unit, ["grams", "troy_ounces"])
  end
end
