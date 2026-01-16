defmodule AurumWeb.DeleteGoldItemTest do
  use AurumWeb.ConnCase, async: true

  @moduletag :skip

  describe "US-005: Delete Gold Item" do
    setup do
      # Create test item when Portfolio context is available
      # {:ok, item} = Aurum.Portfolio.create_item(%{
      #   name: "Item To Delete",
      #   category: :bar,
      #   weight: 50.0,
      #   weight_unit: :grams,
      #   purity: 99.9,
      #   quantity: 1,
      #   purchase_price: Decimal.new("2500.00")
      # })
      # %{item: item}
      :ok
    end

    test "delete button shows confirmation dialog", %{conn: conn} do
      conn
      |> visit("/items/1")
      |> assert_has("button#delete-item")
    end

    test "confirmation dialog states item name", %{conn: conn} do
      conn
      |> visit("/items/1")
      |> click_button("Delete")
      |> assert_has("#confirm-dialog", text: "Item To Delete")
    end

    test "item is removed after confirmation", %{conn: conn} do
      conn
      |> visit("/items/1")
      |> click_button("Delete")
      |> click_button("Confirm")
      |> assert_path("/items")
      |> refute_has("td", text: "Item To Delete")
    end

    test "cancel deletion keeps item", %{conn: conn} do
      conn
      |> visit("/items/1")
      |> click_button("Delete")
      |> click_button("Cancel")
      |> visit("/items")
      |> assert_has("td", text: "Item To Delete")
    end
  end
end
