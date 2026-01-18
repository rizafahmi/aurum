defmodule AurumWeb.ConvertWeightUnitsTest do
  use AurumWeb.ConnCase, async: true

  alias Aurum.Portfolio

  describe "US-009: Convert Weight Units" do
    test "weight unit selector offers grams and troy oz options", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> assert_has("select#item-weight-unit option", text: "grams")
      |> assert_has("select#item-weight-unit option", text: "troy oz")
    end

    test "internal storage normalizes to grams", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "1oz Gold Eagle")
      |> select("Category", option: "Coin")
      |> fill_in("Weight", with: "1")
      |> select("Weight unit", option: "troy oz")
      |> select("Purity", option: "22K")
      |> fill_in("Quantity", with: "1")
      |> fill_in("Purchase price", with: "2000.00")
      |> click_button("Save")

      # Verify item was stored - fetch from DB
      [item] = Portfolio.list_items()
      # Internal storage should normalize to grams: 1 troy oz = 31.1035 grams
      assert Decimal.eq?(item.weight, Decimal.new("31.1035"))
      assert item.weight_unit == :grams
    end

    test "display converts back to user's preferred unit", %{conn: conn} do
      # Create item with troy oz
      {:ok, item} =
        Portfolio.create_item(%{
          name: "Gold Eagle",
          category: :coin,
          weight: Decimal.new("31.1035"),
          weight_unit: :grams,
          purity: 22,
          quantity: 1,
          purchase_price: Decimal.new("2000.00")
        })

      conn
      |> visit("/items/#{item.id}")
      |> assert_has("[data-test='weight']", text: "31.1035 g")
    end

    test "conversion uses 1 troy oz = 31.1035 grams", %{conn: conn} do
      # Create item entered as 1 troy oz
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "1oz Bar")
      |> select("Category", option: "Bar")
      |> fill_in("Weight", with: "1")
      |> select("Weight unit", option: "troy oz")
      |> select("Purity", option: "24K")
      |> fill_in("Quantity", with: "1")
      |> fill_in("Purchase price", with: "2500.00")
      |> click_button("Save")

      [item] = Portfolio.list_items()
      # Verify conversion: 1 troy oz should become 31.1035 grams
      assert Decimal.eq?(item.weight, Decimal.new("31.1035"))
    end
  end
end
