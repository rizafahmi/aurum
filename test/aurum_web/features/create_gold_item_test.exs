defmodule AurumWeb.CreateGoldItemTest do
  use AurumWeb.ConnCase, async: true

  describe "US-001: Create Gold Item" do
    test "displays form with all required fields", %{conn: conn} do
      conn
      |> visit("/items/new")
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

    test "category dropdown has exactly 4 options", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> assert_has("select#item-category option", text: "Bar")
      |> assert_has("select#item-category option", text: "Coin")
      |> assert_has("select#item-category option", text: "Jewelry")
      |> assert_has("select#item-category option", text: "Other")
    end

    test "purity accepts preset karat values", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> assert_has("select#item-purity option", text: "24K")
      |> assert_has("select#item-purity option", text: "22K")
      |> assert_has("select#item-purity option", text: "18K")
      |> assert_has("select#item-purity option", text: "14K")
    end

    test "weight unit selector offers grams and troy oz", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> assert_has("select#item-weight-unit option", text: "grams")
      |> assert_has("select#item-weight-unit option", text: "troy oz")
    end

    test "successfully creates gold item with valid data", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "1oz Gold Bar")
      |> select("Category", option: "Bar")
      |> fill_in("Weight", with: "31.1035")
      |> select("Weight unit", option: "grams")
      |> select("Purity", option: "24K")
      |> fill_in("Quantity", with: "1")
      |> fill_in("Purchase price", with: "2500.00")
      |> click_button("Save")
      |> assert_path("/items")
      |> assert_has("td", text: "1oz Gold Bar")
    end

    test "creates item with optional fields", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Vintage Coin")
      |> select("Category", option: "Coin")
      |> fill_in("Weight", with: "1")
      |> select("Weight unit", option: "troy oz")
      |> select("Purity", option: "22K")
      |> fill_in("Quantity", with: "2")
      |> fill_in("Purchase price", with: "4800.00")
      |> fill_in("Purchase date", with: "2024-01-15")
      |> fill_in("Notes", with: "Inherited from grandfather")
      |> click_button("Save")
      |> assert_path("/items")
      |> assert_has("td", text: "Vintage Coin")
    end

    test "validates weight must be positive", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test Item")
      |> select("Category", option: "Bar")
      |> fill_in("Weight", with: "-5")
      |> select("Purity", option: "24K")
      |> fill_in("Quantity", with: "1")
      |> fill_in("Purchase price", with: "100.00")
      |> click_button("Save")
      |> assert_has("p", text: "must be greater than 0")
    end

    test "validates quantity must be positive", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test Item")
      |> select("Category", option: "Bar")
      |> fill_in("Weight", with: "10")
      |> select("Purity", option: "24K")
      |> fill_in("Quantity", with: "0")
      |> fill_in("Purchase price", with: "100.00")
      |> click_button("Save")
      |> assert_has("p", text: "must be greater than 0")
    end

    test "validates purchase price must be non-negative", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test Item")
      |> select("Category", option: "Bar")
      |> fill_in("Weight", with: "10")
      |> select("Purity", option: "24K")
      |> fill_in("Quantity", with: "1")
      |> fill_in("Purchase price", with: "-50")
      |> click_button("Save")
      |> assert_has("p", text: "must be greater than or equal to 0")
    end
  end
end
