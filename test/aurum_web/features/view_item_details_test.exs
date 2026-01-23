defmodule AurumWeb.ViewItemDetailsTest do
  use AurumWeb.ConnCase, async: true

  describe "US-011: View Item Details" do
    setup do
      {:ok, item} =
        Aurum.Portfolio.create_item(%{
          name: "Detailed Gold Bar",
          category: :bar,
          weight: Decimal.new("100.0"),
          weight_unit: :grams,
          purity: 24,
          quantity: 2,
          purchase_price: Decimal.new("10000.00"),
          purchase_date: ~D[2024-01-15],
          notes: "Special edition"
        })

      %{item: item}
    end

    test "shows all item fields including notes", %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      |> assert_has("h1", text: "Detailed Gold Bar")
      |> assert_has("[data-test='category']", text: "Bar")
      |> assert_has("[data-test='weight']", text: "100")
      |> assert_has("[data-test='purity']", text: "24K")
      |> assert_has("[data-test='quantity']", text: "2")
      |> assert_has("[data-test='purchase-price']")
      |> assert_has("[data-test='purchase-date']", text: "2024-01-15")
      |> assert_has("[data-test='notes']", text: "Special edition")
    end

    test "shows calculated pure gold weight", %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      |> assert_has("[data-test='pure-gold-weight']")
    end

    test "shows current value", %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      |> assert_has("[data-test='current-value']")
    end

    test "shows gain/loss for this item", %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      |> assert_has("[data-test='gain-loss']")
    end

    test "edit button is accessible", %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      |> assert_has("a", text: "Edit")
    end

    test "delete button is accessible", %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      |> assert_has("button#delete-item")
    end

    test "back navigation returns to portfolio list", %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      |> click_link("Back")
      |> assert_path("/items")
    end
  end
end
