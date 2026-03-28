defmodule Aurum.GoldTest do
  use Aurum.DataCase
  import Decimal

  alias Aurum.Gold

  describe "list_holdings/0" do
    test "returns all holdings" do
      holding1 = insert_holding!(name: "Gold Coin 1", category: "coin")
      holding2 = insert_holding!(name: "Gold Bar 1", category: "bar")

      holdings = Gold.list_holdings()

      assert length(holdings) == 2
      assert Enum.any?(holdings, fn h -> h.id == holding1.id end)
      assert Enum.any?(holdings, fn h -> h.id == holding2.id end)
    end

    test "returns empty list when no holdings" do
      holdings = Gold.list_holdings()
      assert holdings == []
    end
  end

  describe "get_holding!/1" do
    test "returns holding when exists" do
      holding = insert_holding!(name: "Gold Coin 1", category: "coin")

      result = Gold.get_holding!(holding.id)

      assert result.id == holding.id
      assert result.name == "Gold Coin 1"
    end

    test "raises when holding does not exist" do
      assert_raise Ecto.NoResultsError, fn ->
        Gold.get_holding!(999)
      end
    end
  end

  describe "create_holding/1" do
    test "creates holding with valid data" do
      params = %{
        name: "Gold Coin 1",
        category: "coin",
        weight: "1.0",
        weight_unit: "troy_ounces",
        purity: "1.0",
        quantity: 1,
        cost_basis: "2000.00",
        purchase_date: "2024-01-01",
        notes: "American Eagle"
      }

      {:ok, holding} = Gold.create_holding(params)

      assert holding.name == "Gold Coin 1"
      assert holding.category == "coin"
      assert Decimal.eq?(holding.weight, Decimal.new("1.0"))
      assert Decimal.eq?(holding.purity, Decimal.new("1.0"))
      assert Decimal.eq?(holding.cost_basis, Decimal.new("2000.00"))
    end

    test "returns error with invalid data" do
      params = %{
        name: "",
        category: "coin",
        weight: "invalid",
        weight_unit: "troy_ounces",
        purity: "1.0",
        quantity: 1,
        cost_basis: "2000.00"
      }

      {:error, changeset} = Gold.create_holding(params)

      assert changeset.errors[:name] != nil
      assert changeset.errors[:weight] != nil
    end
  end

  describe "update_holding/2" do
    test "updates holding with valid data" do
      holding = insert_holding!(name: "Gold Coin 1", category: "coin")

      params = %{
        name: "Updated Gold Coin",
        cost_basis: "2500.00"
      }

      {:ok, updated_holding} = Gold.update_holding(holding, params)

      assert updated_holding.id == holding.id
      assert updated_holding.name == "Updated Gold Coin"
      assert Decimal.eq?(updated_holding.cost_basis, Decimal.new("2500.00"))
    end

    test "returns error with invalid data" do
      holding = insert_holding!(name: "Gold Coin 1", category: "coin")

      params = %{
        name: "",
        weight: "invalid"
      }

      {:error, changeset} = Gold.update_holding(holding, params)

      assert changeset.errors[:name] != nil
      assert changeset.errors[:weight] != nil
    end
  end

  describe "delete_holding/1" do
    test "deletes holding" do
      holding = insert_holding!(name: "Gold Coin 1", category: "coin")

      {:ok, _} = Gold.delete_holding(holding)

      assert_raise Ecto.NoResultsError, fn ->
        Gold.get_holding!(holding.id)
      end
    end
  end

  describe "list_prices/0" do
    test "returns all prices" do
      price1 = insert_price!(spot_price_usd: "2350.50", spot_price_idr: "35257500")
      price2 = insert_price!(spot_price_usd: "2360.00", spot_price_idr: "35400000")

      prices = Gold.list_prices()

      assert length(prices) == 2
      assert Enum.any?(prices, fn p -> p.id == price1.id end)
      assert Enum.any?(prices, fn p -> p.id == price2.id end)
    end
  end

  describe "latest_price/0" do
    test "returns most recent price" do
      insert_price!(spot_price_usd: "2350.50", spot_price_idr: "35257500")
      Process.sleep(10)
      latest = insert_price!(spot_price_usd: "2360.00", spot_price_idr: "35400000")

      result = Gold.latest_price()

      assert result.id == latest.id
      assert Decimal.eq?(result.spot_price_usd, Decimal.new("2360.00"))
    end

    test "returns nil when no prices" do
      result = Gold.latest_price()
      assert is_nil(result)
    end
  end

  # Helper functions

  defp insert_holding!(attrs) do
    params = %{
      name: "Gold Coin",
      category: "coin",
      weight: "1.0",
      weight_unit: "troy_ounces",
      purity: "1.0",
      quantity: 1,
      cost_basis: "2000.00",
      purchase_date: "2024-01-01",
      notes: "Test holding"
    }

    {:ok, holding} = Gold.create_holding(Map.merge(params, Map.new(attrs)))
    holding
  end

  defp insert_price!(attrs) do
    params = %{
      currency: "IDR",
      spot_price_usd: "2350.50",
      spot_price_idr: "35257500",
      exchange_rate: "15000",
      fetched_at: DateTime.utc_now() |> DateTime.truncate(:second)
    }

    merged_params = Map.merge(params, Map.new(attrs))

    {:ok, price} = Gold.create_price(merged_params)
    price
  end
end
