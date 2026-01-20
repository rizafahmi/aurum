defmodule AurumWeb.ConvertWeightUnitsTest do
  use AurumWeb.ConnCase, async: true

  alias Aurum.Portfolio

  describe "US-009: Convert Weight Units" do
    test "quick-add form uses grams as default unit", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Gold Bar")
      |> fill_in("Weight (grams)", with: "31.1035")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "2500.00")
      |> click_button("Add Asset")

      [item] = Portfolio.list_items()
      assert item.weight_unit == :grams
      assert Decimal.eq?(item.weight, Decimal.new("31.1035"))
    end

    test "internal storage normalizes troy oz to grams via context", %{conn: _conn} do
      # Quick-add form doesn't offer troy oz selection, so we test via context directly
      {:ok, _item} =
        Portfolio.create_item(%{
          name: "1oz Gold Eagle",
          category: :coin,
          weight: Decimal.new("1"),
          weight_unit: :troy_oz,
          purity: 22,
          quantity: 1,
          purchase_price: Decimal.new("2000.00")
        })

      [item] = Portfolio.list_items()
      # Internal storage should normalize to grams: 1 troy oz = 31.1035 grams
      assert Decimal.eq?(item.weight, Decimal.new("31.1035"))
      assert item.weight_unit == :grams
    end

    test "display shows weight in grams", %{conn: conn} do
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

    test "conversion uses 1 troy oz = 31.1035 grams via context" do
      # Test conversion logic directly via context since quick form doesn't expose troy oz
      {:ok, _item} =
        Portfolio.create_item(%{
          name: "1oz Bar",
          category: :bar,
          weight: Decimal.new("1"),
          weight_unit: :troy_oz,
          purity: 24,
          quantity: 1,
          purchase_price: Decimal.new("2500.00")
        })

      [item] = Portfolio.list_items()
      # Verify conversion: 1 troy oz should become 31.1035 grams
      assert Decimal.eq?(item.weight, Decimal.new("31.1035"))
    end
  end
end
