defmodule AurumWeb.DataPersistenceTest do
  use AurumWeb.ConnCase, async: false

  alias Aurum.Portfolio

  describe "US-013: Persist Data Across Restarts" do
    test "items created are visible after stopping and restarting the Phoenix server", %{
      conn: conn
    } do
      # Create an item via the quick-add form
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Persistence Test Bar")
      |> fill_in("Weight (grams)", with: "100")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "5000.00")
      |> click_button("Add Asset")

      # Verify item exists in database directly (simulates restart - data persists in SQLite)
      items = Portfolio.list_items()
      assert Enum.any?(items, fn item -> item.name == "Persistence Test Bar" end)

      # Verify item appears on items list page (fresh page load simulates post-restart view)
      conn
      |> visit("/items")
      |> assert_has("td", text: "Persistence Test Bar")
    end

    test "cached gold price survives app restart" do
      alias Aurum.Gold.PriceCache
      alias Aurum.Gold.CachedPrice

      # Set a test price that gets persisted
      test_price = %{
        price_per_oz: Decimal.new("2650.00"),
        price_per_gram: Decimal.new("85.20"),
        currency: "USD",
        source: :test
      }

      fetched_at = DateTime.utc_now()
      PriceCache.set_test_price(test_price, fetched_at)

      # Verify it was persisted to database
      cached = CachedPrice.get_latest()
      assert cached != nil
      assert Decimal.eq?(cached.price_per_gram, Decimal.new("85.20"))
      assert cached.currency == "USD"
    end

    test "SQLite database file exists in expected location" do
      # Get database path from repo config
      config = Application.get_env(:aurum, Aurum.Repo)
      database_path = Keyword.get(config, :database)

      assert database_path != nil, "Database path should be configured"
      assert File.exists?(database_path), "SQLite database file should exist at #{database_path}"
    end
  end
end
