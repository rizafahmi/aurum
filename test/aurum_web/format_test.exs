defmodule AurumWeb.FormatTest do
  use ExUnit.Case, async: true

  alias AurumWeb.Format

  describe "currency/1" do
    test "formats decimal with Rp prefix" do
      assert Format.currency(Decimal.new("1234.56")) == "Rp1,234.56"
    end

    test "adds comma separators for thousands" do
      assert Format.currency(Decimal.new("1000000")) == "Rp1,000,000.00"
    end

    test "rounds to 2 decimal places" do
      assert Format.currency(Decimal.new("99.999")) == "Rp100.00"
    end

    test "handles negative values" do
      assert Format.currency(Decimal.new("-500.50")) == "Rp-500.50"
    end

    test "returns dash for nil" do
      assert Format.currency(nil) == "—"
    end

    test "pads decimals to 2 places" do
      assert Format.currency(Decimal.new("100")) == "Rp100.00"
      assert Format.currency(Decimal.new("100.5")) == "Rp100.50"
    end
  end
end
