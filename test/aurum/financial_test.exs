defmodule Aurum.FinancialTest do
  use Aurum.DataCase

  describe "pure_gold_weight/2" do
    test "calculates pure gold weight correctly" do
      weight = Decimal.new("10.0")
      purity = Decimal.new("0.75")  # 18K gold

      result = Aurum.Financial.pure_gold_weight(weight, purity)
      expected = Decimal.new("7.5")

      assert Decimal.eq?(result, expected)
    end

    test "handles 24K gold (100% purity)" do
      weight = Decimal.new("10.0")
      purity = Decimal.new("1.0")

      result = Aurum.Financial.pure_gold_weight(weight, purity)
      expected = Decimal.new("10.0")

      assert Decimal.eq?(result, expected)
    end
  end

  describe "calculate_roi/2" do
    test "calculates ROI for positive gains" do
      current_value = Decimal.new("1200")
      cost_basis = Decimal.new("1000")

      result = Aurum.Financial.calculate_roi(current_value, cost_basis)
      expected = Decimal.new("20")

      assert Decimal.eq?(result, expected)
    end

    test "calculates ROI for losses" do
      current_value = Decimal.new("800")
      cost_basis = Decimal.new("1000")

      result = Aurum.Financial.calculate_roi(current_value, cost_basis)
      expected = Decimal.new("-20")

      assert Decimal.eq?(result, expected)
    end

    test "handles zero cost basis" do
      current_value = Decimal.new("100")
      cost_basis = Decimal.new("0")

      result = Aurum.Financial.calculate_roi(current_value, cost_basis)
      expected = Decimal.new("0")

      assert Decimal.eq?(result, expected)
    end
  end

  describe "convert_weight/3" do
    test "converts grams to troy ounces" do
      weight = Decimal.new("31.1034768")  # 1 troy ounce in grams

      result = Aurum.Financial.convert_weight(weight, :grams, :troy_ounces)
      expected = Decimal.new("1.0")

      assert Decimal.eq?(result, expected)
    end

    test "converts troy ounces to grams" do
      weight = Decimal.new("1.0")

      result = Aurum.Financial.convert_weight(weight, :troy_ounces, :grams)
      expected = Decimal.new("31.1034768")

      assert Decimal.eq?(result, expected)
    end
  end

  describe "karat_to_purity/1" do
    test "converts 24K to 1.0" do
      result = Aurum.Financial.karat_to_purity(24)
      expected = Decimal.new("1.0")

      assert Decimal.eq?(result, expected)
    end

    test "converts 22K to 0.9167" do
      result = Aurum.Financial.karat_to_purity(22)
      expected = Decimal.new("0.9167")

      assert Decimal.eq?(result, expected)
    end

    test "converts 18K to 0.75" do
      result = Aurum.Financial.karat_to_purity(18)
      expected = Decimal.new("0.75")

      assert Decimal.eq?(result, expected)
    end

    test "converts 14K to 0.5833" do
      result = Aurum.Financial.karat_to_purity(14)
      expected = Decimal.new("0.5833")

      assert Decimal.eq?(result, expected)
    end

    test "handles custom karat values" do
      result = Aurum.Financial.karat_to_purity(20)
      expected = Decimal.div(Decimal.new("20"), Decimal.new("24"))

      assert Decimal.eq?(result, expected)
    end
  end
end
