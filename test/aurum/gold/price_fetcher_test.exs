defmodule Aurum.Gold.PriceFetcherTest do
  use Aurum.DataCase

  describe "start_link/1" do
    test "GenServer is running" do
      pid = Process.whereis(Aurum.Gold.PriceFetcher)
      assert is_pid(pid)
      assert Process.alive?(pid)
    end
  end

  describe "fetch_prices/0" do
    test "fetches gold price and exchange rate" do
      pid = Process.whereis(Aurum.Gold.PriceFetcher)

      # Trigger a price fetch
      send(pid, :fetch_prices)

      # Wait for the fetch to complete
      Process.sleep(100)

      # Verify that price was stored in database
      prices = Aurum.Repo.all(Aurum.Gold.Price)
      refute prices == []
    end
  end

  describe "periodic fetching" do
    test "fetches prices periodically" do
      pid = Process.whereis(Aurum.Gold.PriceFetcher)

      # Trigger immediate fetch
      send(pid, :fetch_prices)
      Process.sleep(100)

      # Trigger another fetch
      send(pid, :fetch_prices)
      Process.sleep(100)

      # Verify multiple price records
      prices = Aurum.Repo.all(Aurum.Gold.Price)
      assert Enum.count(prices) >= 2
    end
  end
end
