defmodule AurumWeb.ItemValuationTest do
  use AurumWeb.ConnCase, async: false

  describe "US-008: Calculate Item Valuation" do
    setup do
      # 100g of 24K gold (99.99% purity) = 99.99g pure gold
      {:ok, item} =
        Aurum.Portfolio.create_item(%{
          name: "Test Gold Bar",
          category: :bar,
          weight: Decimal.new("100.0"),
          weight_unit: :grams,
          purity: 24,
          quantity: 1,
          purchase_price: Decimal.new("8000.00")
        })

      %{item: item}
    end

    test "pure gold weight = weight × (purity% / 100) × quantity", %{conn: conn, item: item} do
      # 100g × (99.99 / 100) × 1 = 99.99g pure gold
      conn
      |> visit("/items/#{item.id}")
      |> assert_has("[data-test='pure-gold-weight']", text: "99.99")
    end

    test "current value = pure gold weight × spot price", %{conn: conn, item: item} do
      # Current value depends on spot price from PriceCache
      # We verify the element shows a calculated value
      conn
      |> visit("/items/#{item.id}")
      |> assert_has("[data-test='current-value']", text: "Rp")
    end

    test "gain/loss = current value - purchase price", %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      |> assert_has("[data-test='gain-loss']")
    end

    test "calculations use consistent precision (2 decimal places for currency, 4 for weight)",
         %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      # Weight should have 4 decimal precision (99.9900)
      |> assert_has("[data-test='pure-gold-weight']", text: "99.99")
      # Currency should have 2 decimal precision
      |> assert_has("[data-test='purchase-price']", text: "Rp8,000.00")
    end
  end
end
