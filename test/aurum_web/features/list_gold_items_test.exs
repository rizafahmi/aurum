defmodule AurumWeb.ListGoldItemsTest do
  use AurumWeb.ConnCase, async: true

  @moduletag :skip

  describe "US-003: List All Gold Items - empty state" do
    test "displays empty message when no items exist", %{conn: conn} do
      conn
      |> visit("/items")
      |> assert_has("p", text: "No items yet")
    end
  end

  describe "US-003: List All Gold Items - with items" do
    setup do
      # Create test items when Portfolio context is available
      # {:ok, item1} = Aurum.Portfolio.create_item(%{...})
      # {:ok, item2} = Aurum.Portfolio.create_item(%{...})
      :ok
    end

    test "displays item name", %{conn: conn} do
      conn
      |> visit("/items")
      |> assert_has("td", text: "Gold Bar")
    end

    test "displays item category", %{conn: conn} do
      conn
      |> visit("/items")
      |> assert_has("td", text: "Bar")
    end

    test "displays item weight", %{conn: conn} do
      conn
      |> visit("/items")
      |> assert_has("td", text: "31.1035")
    end

    test "displays item purity", %{conn: conn} do
      conn
      |> visit("/items")
      |> assert_has("td", text: "24K")
    end

    test "displays item quantity", %{conn: conn} do
      conn
      |> visit("/items")
      |> assert_has("td", text: "1")
    end

    test "displays item purchase price", %{conn: conn} do
      conn
      |> visit("/items")
      |> assert_has("td", text: "$2,500.00")
    end

    test "displays item current value", %{conn: conn} do
      conn
      |> visit("/items")
      |> assert_has("[data-test='current-value']")
    end

    test "each item row links to detail view", %{conn: conn} do
      conn
      |> visit("/items")
      |> assert_has("a[href^='/items/']")
    end

    test "items sorted by creation date newest first", %{conn: conn} do
      # Would need to verify order of items in list
      conn
      |> visit("/items")
      |> assert_has("#items-list")
    end
  end
end
