defmodule Aurum.Portfolio do
  @moduledoc """
  Context for managing gold portfolio items.

  Provides CRUD operations and valuation calculations for gold holdings.
  """
  import Ecto.Query
  alias Aurum.Portfolio.{Item, Valuation}
  alias Aurum.Repo

  @default_spot_price Decimal.new("85.00")

  @doc """
  Returns the default spot price per gram used for valuations.
  """
  @spec default_spot_price() :: Decimal.t()
  def default_spot_price, do: @default_spot_price

  @doc """
  Returns all items ordered by creation date (newest first).
  """
  @spec list_items() :: [Item.t()]
  def list_items do
    Item
    |> order_by(desc: :inserted_at)
    |> Repo.all()
  end

  @doc """
  Returns the item with its full valuation data.

  ## Returns
  A tuple of `{item, valuation}` where valuation contains:
  - `:pure_gold_grams` - Pure gold weight in grams
  - `:current_value` - Current market value
  - `:gain_loss` - Absolute gain/loss
  - `:gain_loss_percent` - Percentage gain/loss (nil if purchase price is zero)
  """
  @spec valuate_item(Item.t(), Decimal.t()) :: {Item.t(), Valuation.valuation_result()}
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

  @doc """
  Returns all items with their current value populated.
  """
  @spec list_items_with_current_values(Decimal.t()) :: [Item.t()]
  def list_items_with_current_values(spot_price \\ @default_spot_price) do
    list_items()
    |> Enum.map(fn item ->
      {_item, valuation} = valuate_item(item, spot_price)
      %{item | current_value: valuation.current_value}
    end)
  end

  @doc """
  Returns items and aggregated portfolio summary for the dashboard.

  ## Returns
  A tuple of `{items, summary}` where summary is nil for empty portfolios.
  """
  @spec dashboard_summary(Decimal.t()) :: {[Item.t()], map() | nil}
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

  @doc """
  Gets a single item by ID. Raises if not found.
  """
  @spec get_item!(term()) :: Item.t()
  def get_item!(id), do: Repo.get!(Item, id)

  @doc """
  Creates a new gold item.

  ## Returns
  - `{:ok, item}` on success
  - `{:error, changeset}` on validation failure
  """
  @spec create_item(map()) :: {:ok, Item.t()} | {:error, Ecto.Changeset.t()}
  def create_item(attrs \\ %{}) do
    %Item{}
    |> Item.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Returns a changeset for tracking item changes.
  """
  @spec change_item(Item.t(), map()) :: Ecto.Changeset.t()
  def change_item(%Item{} = item, attrs \\ %{}) do
    Item.changeset(item, attrs)
  end

  @doc """
  Updates an existing gold item.

  ## Returns
  - `{:ok, item}` on success
  - `{:error, changeset}` on validation failure
  """
  @spec update_item(Item.t(), map()) :: {:ok, Item.t()} | {:error, Ecto.Changeset.t()}
  def update_item(%Item{} = item, attrs) do
    item
    |> Item.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a gold item.

  ## Returns
  - `{:ok, item}` on success
  - `{:error, changeset}` on failure
  """
  @spec delete_item(Item.t()) :: {:ok, Item.t()} | {:error, Ecto.Changeset.t()}
  def delete_item(%Item{} = item) do
    Repo.delete(item)
  end
end
