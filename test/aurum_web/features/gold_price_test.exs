defmodule AurumWeb.GoldPriceTest do
  use AurumWeb.ConnCase, async: true

  @moduletag :skip

  describe "US-006: Fetch Live Gold Price" do
    test "displays gold spot price on dashboard", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("#gold-price")
    end

    test "displays last updated timestamp", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("#price-last-updated")
    end

    test "handles API errors gracefully", %{conn: conn} do
      # When API fails, should show cached price or placeholder
      conn
      |> visit("/")
      |> refute_has(".error-crash")
    end
  end

  describe "US-010: Refresh Gold Price Manually" do
    test "displays refresh button near price", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("button#refresh-price")
    end

    test "shows loading state during refresh", %{conn: conn} do
      conn
      |> visit("/")
      |> click_button("Refresh")
      |> assert_has("#price-loading")
    end
  end

  describe "US-007: Display Stale Price Indicator" do
    test "shows stale indicator when price is old", %{conn: conn} do
      # This would require setting up a stale price in the cache
      conn
      |> visit("/")
      |> assert_has("#stale-price-indicator")
    end
  end
end
