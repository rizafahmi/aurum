defmodule Aurum.Gold.CachedPriceTest do
  use Aurum.DataCase, async: true

  alias Aurum.Gold.CachedPrice

  describe "default currency" do
    test "defaults to IDR when currency is not provided" do
      price_data = %{
        price_per_oz: Decimal.new("2650.50"),
        price_per_gram: Decimal.new("85.21"),
        source: :test
      }

      {:ok, cached} = CachedPrice.save(price_data, DateTime.utc_now())

      assert cached.currency == "IDR"
    end

    test "schema field defaults to IDR" do
      cached = %CachedPrice{}
      assert cached.currency == "IDR"
    end
  end
end
