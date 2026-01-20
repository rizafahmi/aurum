defmodule AurumWeb.CreateGoldItemTest do
  use AurumWeb.ConnCase, async: true

  describe "US-001: Create Gold Item" do
    test "displays quick-add form with required fields", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> assert_has("input#item-name")
      |> assert_has("input#item-weight")
      |> assert_has("select#item-purity")
      |> assert_has("input#item-purchase-price")
    end

    test "purity accepts preset karat values", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> assert_has("select#item-purity option", text: "24K")
      |> assert_has("select#item-purity option", text: "22K")
      |> assert_has("select#item-purity option", text: "18K")
      |> assert_has("select#item-purity option", text: "14K")
    end

    test "successfully creates gold item with valid data", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "1oz Gold Bar")
      |> fill_in("Weight (grams)", with: "31.1035")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "2500.00")
      |> click_button("Add Asset")
      |> assert_path("/items")
      |> assert_has("td", text: "1oz Gold Bar")
    end

    test "creates item with different purity", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Vintage Coin")
      |> fill_in("Weight (grams)", with: "31.1035")
      |> select("Purity", option: "22K")
      |> fill_in("Purchase price", with: "4800.00")
      |> click_button("Add Asset")
      |> assert_path("/items")
      |> assert_has("td", text: "Vintage Coin")
    end

    test "validates weight must be positive", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test Item")
      |> fill_in("Weight (grams)", with: "-5")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "100.00")
      |> click_button("Add Asset")
      |> assert_has("p", text: "must be greater than 0")
    end

    test "validates purchase price must be non-negative", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test Item")
      |> fill_in("Weight (grams)", with: "10")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "-50")
      |> click_button("Add Asset")
      |> assert_has("p", text: "must be greater than or equal to 0")
    end
  end
end
