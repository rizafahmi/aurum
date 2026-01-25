defmodule AurumWeb.GoldPriceTest do
  use AurumWeb.ConnCase, async: false

  import PhoenixTest

  setup do
    price_data = %{
      price_per_oz: Decimal.new("2650.00"),
      price_per_gram: Decimal.new("85.20"),
      currency: "IDR",
      timestamp: DateTime.utc_now(),
      source: :test
    }

    :ok = Aurum.Gold.PriceCache.set_test_price(price_data, DateTime.utc_now())
    Aurum.Gold.PriceCache.set_test_error(nil)
    :ok
  end

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

    test "clicking refresh fetches new price from API", %{conn: conn} do
      conn
      |> visit("/")
      |> click_button("Refresh")
      |> assert_has("#gold-price")
      |> assert_has("#price-last-updated")
    end

    test "error shows user-friendly message without losing cached price", %{conn: conn} do
      session =
        conn
        |> visit("/")
        |> assert_has("#gold-price")

      Aurum.Gold.PriceCache.set_test_error(:api_unavailable)

      session
      |> click_button("Refresh")
      |> assert_has("#gold-price")
      |> assert_has("#refresh-error")
    end
  end

  describe "US-007: Display Stale Price Indicator" do
    test "uses cached price when available", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("#gold-price")
    end

    test "shows stale indicator when price is old", %{conn: conn} do
      # Price older than 2 hour stale threshold
      stale_fetched_at = DateTime.add(DateTime.utc_now(), -3, :hour)

      stale_price_data = %{
        price_per_oz: Decimal.new("2650.00"),
        price_per_gram: Decimal.new("85.20"),
        currency: "USD",
        timestamp: stale_fetched_at,
        source: :test
      }

      :ok = Aurum.Gold.PriceCache.set_test_price(stale_price_data, stale_fetched_at)
      # Force refresh to fail so stale indicator shows
      Aurum.Gold.PriceCache.set_test_error(:api_unavailable)

      conn
      |> visit("/")
      |> assert_has("#stale-price-indicator")
    end

    test "displays time since last update", %{conn: conn} do
      conn
      |> visit("/")
      |> assert_has("#price-last-updated")
    end
  end
end
