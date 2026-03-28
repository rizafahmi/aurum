defmodule Aurum.PortfolioTest do
  use Aurum.DataCase
  import Decimal

  describe "total_value_troy_ounces/2" do
    test "calculates total portfolio value correctly" do
      spot_price = Decimal.new("2350.50")

      holdings = [
        %Aurum.Gold.Holding{
          name: "Gold Coin 1",
          category: "coin",
          weight: Decimal.new("1.0"),
          weight_unit: "troy_ounces",
          purity: Decimal.new("1.0"),
          quantity: 1,
          cost_basis: Decimal.new("2000.00"),
          purchase_date: ~D[2024-01-01],
          notes: "American Eagle"
        },
        %Aurum.Gold.Holding{
          name: "Gold Bar 1",
          category: "bar",
          weight: Decimal.new("10.0"),
          weight_unit: "troy_ounces",
          purity: Decimal.new("0.9167"),
          quantity: 1,
          cost_basis: Decimal.new("20000.00"),
          purchase_date: ~D[2024-02-01],
          notes: "10 oz bar"
        }
      ]

      result = Aurum.Portfolio.total_value_troy_ounces(holdings, spot_price)
      expected = Decimal.new("23897.5335000")

      assert Decimal.eq?(result, expected)
    end

    test "handles empty holdings list" do
      spot_price = Decimal.new("2350.50")
      holdings = []

      result = Aurum.Portfolio.total_value_troy_ounces(holdings, spot_price)
      expected = Decimal.new("0")

      assert Decimal.eq?(result, expected)
    end
  end

  describe "total_cost_basis_troy_ounces/1" do
    test "calculates total cost basis correctly" do
      holdings = [
        %Aurum.Gold.Holding{
          name: "Gold Coin 1",
          category: "coin",
          weight: Decimal.new("1.0"),
          weight_unit: "troy_ounces",
          purity: Decimal.new("1.0"),
          quantity: 1,
          cost_basis: Decimal.new("2000.00"),
          purchase_date: ~D[2024-01-01],
          notes: "American Eagle"
        },
        %Aurum.Gold.Holding{
          name: "Gold Bar 1",
          category: "bar",
          weight: Decimal.new("10.0"),
          weight_unit: "troy_ounces",
          purity: Decimal.new("0.9167"),
          quantity: 1,
          cost_basis: Decimal.new("20000.00"),
          purchase_date: ~D[2024-02-01],
          notes: "10 oz bar"
        }
      ]

      result = Aurum.Portfolio.total_cost_basis_troy_ounces(holdings)
      expected = Decimal.new("22000.00")

      assert Decimal.eq?(result, expected)
    end

    test "handles empty holdings list" do
      holdings = []

      result = Aurum.Portfolio.total_cost_basis_troy_ounces(holdings)
      expected = Decimal.new("0")

      assert Decimal.eq?(result, expected)
    end
  end

  describe "portfolio_roi/2" do
    test "calculates portfolio ROI correctly" do
      spot_price = Decimal.new("2350.50")

      holdings = [
        %Aurum.Gold.Holding{
          name: "Gold Coin 1",
          category: "coin",
          weight: Decimal.new("1.0"),
          weight_unit: "troy_ounces",
          purity: Decimal.new("1.0"),
          quantity: 1,
          cost_basis: Decimal.new("2000.00"),
          purchase_date: ~D[2024-01-01],
          notes: "American Eagle"
        }
      ]

      result = Aurum.Portfolio.portfolio_roi(holdings, spot_price)
      expected = Decimal.new("17.525")

      assert Decimal.eq?(result, expected)
    end

    test "handles losses correctly" do
      spot_price = Decimal.new("2000.00")

      holdings = [
        %Aurum.Gold.Holding{
          name: "Gold Coin 1",
          category: "coin",
          weight: Decimal.new("1.0"),
          weight_unit: "troy_ounces",
          purity: Decimal.new("1.0"),
          quantity: 1,
          cost_basis: Decimal.new("2500.00"),
          purchase_date: ~D[2024-01-01],
          notes: "Gold Coin"
        }
      ]

      result = Aurum.Portfolio.portfolio_roi(holdings, spot_price)
      expected = Decimal.new("-20")

      assert Decimal.eq?(result, expected)
    end

    test "handles zero cost basis" do
      spot_price = Decimal.new("2350.50")

      holdings = [
        %Aurum.Gold.Holding{
          name: "Gold Coin 1",
          category: "coin",
          weight: Decimal.new("1.0"),
          weight_unit: "troy_ounces",
          purity: Decimal.new("1.0"),
          quantity: 1,
          cost_basis: Decimal.new("0.00"),
          purchase_date: ~D[2024-01-01],
          notes: "Gold Coin"
        }
      ]

      result = Aurum.Portfolio.portfolio_roi(holdings, spot_price)
      expected = Decimal.new("0")

      assert Decimal.eq?(result, expected)
    end
  end

  describe "total_pure_weight_troy_ounces/1" do
    test "calculates total pure gold weight correctly" do
      holdings = [
        %Aurum.Gold.Holding{
          name: "Gold Coin 1",
          category: "coin",
          weight: Decimal.new("1.0"),
          weight_unit: "troy_ounces",
          purity: Decimal.new("1.0"),
          quantity: 1,
          cost_basis: Decimal.new("2000.00"),
          purchase_date: ~D[2024-01-01],
          notes: "American Eagle"
        },
        %Aurum.Gold.Holding{
          name: "Gold Bar 1",
          category: "bar",
          weight: Decimal.new("10.0"),
          weight_unit: "troy_ounces",
          purity: Decimal.new("0.9167"),
          quantity: 1,
          cost_basis: Decimal.new("20000.00"),
          purchase_date: ~D[2024-02-01],
          notes: "10 oz bar"
        }
      ]

      result = Aurum.Portfolio.total_pure_weight_troy_ounces(holdings)
      expected = Decimal.new("10.167")

      assert Decimal.eq?(result, expected)
    end

    test "handles empty holdings list" do
      holdings = []

      result = Aurum.Portfolio.total_pure_weight_troy_ounces(holdings)
      expected = Decimal.new("0")

      assert Decimal.eq?(result, expected)
    end
  end
end
