defmodule Aurum.Portfolio do
  import Ecto.Query
  alias Aurum.Repo
  alias Aurum.Portfolio.{Item, Valuation}

  @default_spot_price Decimal.new("85.00")

  def list_items do
    Item
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  def dashboard_summary(spot_price \\ @default_spot_price) do
    items = list_items()
    summary = calculate_summary(items, spot_price)
    {items, summary}
  end

  defp calculate_summary([], _spot_price), do: nil

  defp calculate_summary(items, spot_price) do
    {valuations, purchase_prices} =
      Enum.reduce(items, {[], []}, fn item, {vals, prices} ->
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

        {[valuation | vals], [item.purchase_price | prices]}
      end)

    Valuation.aggregate_portfolio(Enum.reverse(valuations), Enum.reverse(purchase_prices))
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
end
