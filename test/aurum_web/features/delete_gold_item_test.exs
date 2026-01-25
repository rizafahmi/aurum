defmodule AurumWeb.DeleteGoldItemTest do
  use AurumWeb.ConnCase, async: false

  describe "US-005: Delete Gold Item" do
    setup do
      {:ok, item} =
        Aurum.Portfolio.create_item(%{
          name: "Item To Delete",
          category: :bar,
          weight: Decimal.new("50.0"),
          weight_unit: :grams,
          purity: 24,
          quantity: 1,
          purchase_price: Decimal.new("2500.00")
        })

      %{item: item}
    end

    test "delete button shows confirmation dialog", %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      |> assert_has("button#delete-item")
      |> click_button("Delete")
      |> assert_has("#confirm-dialog")
    end

    test "confirmation dialog states item name", %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      |> click_button("Delete")
      |> assert_has("#confirm-dialog", text: "Item To Delete")
    end

    test "item is removed after confirmation", %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      |> click_button("Delete")
      |> click_button("Confirm")
      |> assert_path("/items")
      |> refute_has("td", text: "Item To Delete")
    end

    test "cancel deletion keeps item", %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      |> click_button("Delete")
      |> click_button("Cancel")
      |> refute_has("#confirm-dialog")
      |> visit("/items")
      |> assert_has("td", text: "Item To Delete")
    end

    test "user is redirected to portfolio list after deletion", %{conn: conn, item: item} do
      conn
      |> visit("/items/#{item.id}")
      |> click_button("Delete")
      |> click_button("Confirm")
      |> assert_path("/items")
    end
  end
end
