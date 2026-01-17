defmodule Aurum.Portfolio do
  @moduledoc """
  Context for managing gold portfolio items.
  """
  import Ecto.Query
  alias Aurum.Repo
  alias Aurum.Portfolio.{Item, Valuation}

  @default_spot_price Decimal.new("85.00")

  def default_spot_price, do: @default_spot_price

  def list_items do
    Item
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the item with its full valuation data.
  """
  def valuate_item(%Item{} = item, spot_price \\ @default_spot_price) do
    purity = Valuation.karat_to_purity(item.purity)

    valuation =
      Valuation.valuate_item(
        item.weight,
        item.weight_unit,
        purity,
        item.quantity,
        item.purchase_price,
        spot_price
      )

    {item, valuation}
  end

  def list_items_with_current_values(spot_price \\ @default_spot_price) do
    list_items()
    |> Enum.map(fn item ->
      {_item, valuation} = valuate_item(item, spot_price)
      %{item | current_value: valuation.current_value}
    end)
  end

  def dashboard_summary(spot_price \\ @default_spot_price) do
    items = list_items()
    summary = calculate_summary(items, spot_price)
    {items, summary}
  end

  defp calculate_summary([], _spot_price), do: nil

  defp calculate_summary(items, spot_price) do
    {valuations, purchase_prices} =
      items
      |> Enum.map(fn item ->
        {_item, valuation} = valuate_item(item, spot_price)
        {valuation, item.purchase_price}
      end)
      |> Enum.unzip()

    Valuation.aggregate_portfolio(valuations, purchase_prices)
  end

  def get_item!(id), do: Repo.get!(Item, id)

  def create_item(attrs \\ %{}) do
    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert()
  end

  def change_item(%Item{} = item, attrs \\ %{}) do
    Item.changeset(item, attrs)
  end

  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
  end

  def delete_item(%Item{} = item) do
    Repo.delete(item)
  end
end
