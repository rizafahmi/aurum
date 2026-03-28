defmodule Aurum.CurrencyTest do
  use Aurum.DataCase
  import Decimal

  describe "usd_to_idr/2" do
    test "converts USD to IDR correctly" do
      amount_usd = Decimal.new("100")
      exchange_rate = Decimal.new("15000")

      result = Aurum.Currency.usd_to_idr(amount_usd, exchange_rate)
      expected = Decimal.new("1500000")

      assert Decimal.eq?(result, expected)
    end

    test "handles zero amount" do
      amount_usd = Decimal.new("0")
      exchange_rate = Decimal.new("15000")

      result = Aurum.Currency.usd_to_idr(amount_usd, exchange_rate)
      expected = Decimal.new("0")

      assert Decimal.eq?(result, expected)
    end
  end

  describe "round_to_nearest_thousand/1" do
    test "rounds to nearest thousand" do
      amount = Decimal.new("1234567")
      expected = Decimal.new("1235000")

      result = Aurum.Currency.round_to_nearest_thousand(amount)
      assert Decimal.eq?(result, expected)
    end

    test "handles exact thousand" do
      amount = Decimal.new("15000")
      expected = Decimal.new("15000")

      result = Aurum.Currency.round_to_nearest_thousand(amount)
      assert Decimal.eq?(result, expected)
    end

    test "handles less than 500" do
      amount = Decimal.new("499")
      expected = Decimal.new("0")

      result = Aurum.Currency.round_to_nearest_thousand(amount)
      assert Decimal.eq?(result, expected)
    end
  end

  describe "format_idr/1" do
    test "adds thousand separators" do
      amount = Decimal.new("123456789")

      result = Aurum.Currency.format_idr(amount)
      expected = "123,456,789"

      assert result == expected
    end

    test "handles zero" do
      amount = Decimal.new("0")

      result = Aurum.Currency.format_idr(amount)
      expected = "0"

      assert result == expected
    end
  end
end
