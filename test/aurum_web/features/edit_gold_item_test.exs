defmodule AurumWeb.EditGoldItemTest do
  use AurumWeb.ConnCase, async: true

  @moduletag :skip

  describe "US-004: Edit Gold Item" do
    setup do
      # Create test item when Portfolio context is available
      # {:ok, item} = Aurum.Portfolio.create_item(%{
      #   name: "Original Name",
      #   category: :bar,
      #   weight: 100.0,
      #   weight_unit: :grams,
      #   purity: 99.9,
      #   quantity: 1,
      #   purchase_price: Decimal.new("5000.00")
      # })
      # %{item: item}
      :ok
    end

    test "edit form pre-populates with existing data", %{conn: conn} do
      conn
      |> visit("/items/1/edit")
      |> assert_has("input#item-name[value='Original Name']")
    end

    test "all fields from creation are editable", %{conn: conn} do
      conn
      |> visit("/items/1/edit")
      |> assert_has("input#item-name")
      |> assert_has("select#item-category")
      |> assert_has("input#item-weight")
      |> assert_has("select#item-weight-unit")
      |> assert_has("select#item-purity")
      |> assert_has("input#item-quantity")
      |> assert_has("input#item-purchase-price")
      |> assert_has("input#item-purchase-date")
      |> assert_has("textarea#item-notes")
    end

    test "successfully updates item with new data", %{conn: conn} do
      conn
      |> visit("/items/1/edit")
      |> fill_in("Name", with: "Updated Name")
      |> click_button("Save")
      |> assert_path("/items")
      |> assert_has("td", text: "Updated Name")
    end

    test "validation rules match creation form", %{conn: conn} do
      conn
      |> visit("/items/1/edit")
      |> fill_in("Weight", with: "-10")
      |> click_button("Save")
      |> assert_has("p", text: "must be greater than 0")
    end

    test "cancel button returns to previous view without saving", %{conn: conn} do
      conn
      |> visit("/items/1/edit")
      |> fill_in("Name", with: "Should Not Save")
      |> click_link("Cancel")
      |> refute_has("td", text: "Should Not Save")
    end
  end
end
