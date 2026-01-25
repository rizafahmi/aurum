defmodule AurumWeb.PortfolioDashboardTest do
  use AurumWeb.ConnCase, async: false

  describe "US-002: View Portfolio Dashboard - empty state" do
    test "shows empty state when no items exist", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("#empty-portfolio")
      |> assert_has("a", text: "ADD FIRST ITEM")
    end
  end

  describe "US-002: View Portfolio Dashboard - with items" do
    setup do
      {:ok, _item} =
        Aurum.Portfolio.create_item(%{
          name: "Gold Bar",
          category: :bar,
          weight: "100",
          weight_unit: :grams,
          purity: 24,
          quantity: 1,
          purchase_price: "5000"
        })

      :ok
    end

    test "displays total pure gold weight in grams", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("#total-gold-weight")
    end

    test "displays total invested amount", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("#total-invested")
    end

    test "displays current total value", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("#total-current-value")
    end

    test "displays unrealized gain/loss in absolute value", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("#gain-loss-amount")
    end

    test "displays unrealized gain/loss as percentage", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("#gain-loss-percent")
    end
  end
end
