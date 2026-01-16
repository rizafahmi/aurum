defmodule Aurum.Portfolio.ValuationTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Aurum.Portfolio.Valuation

  describe "pure_gold_weight/4" do
    test "calculates correctly for 24K gold" do
      result = Valuation.pure_gold_weight(10, :grams, 99.99, 1)
      assert Decimal.eq?(result, Decimal.new("9.9990"))
    end

    test "calculates correctly for 22K gold" do
      result = Valuation.pure_gold_weight(10, :grams, 91.67, 1)
      assert Decimal.eq?(result, Decimal.new("9.1670"))
    end

    test "multiplies by quantity" do
      result = Valuation.pure_gold_weight(10, :grams, 100, 5)
      assert Decimal.eq?(result, Decimal.new("50.0000"))
    end

    test "converts troy oz to grams" do
      result = Valuation.pure_gold_weight(1, :troy_oz, 100, 1)
      assert Decimal.eq?(result, Decimal.new("31.1035"))
    end

    test "handles tiny weights" do
      result = Valuation.pure_gold_weight(0.001, :grams, 99.99, 1)
      assert Decimal.gt?(result, Decimal.new("0"))
      assert Decimal.lt?(result, Decimal.new("0.01"))
    end

    test "handles large quantities" do
      result = Valuation.pure_gold_weight(100, :grams, 99.99, 10_000)
      assert Decimal.eq?(result, Decimal.new("999900.0000"))
    end
  end

  describe "current_value/2" do
    test "calculates value correctly" do
      pure_grams = Decimal.new("31.1035")
      price_per_gram = Decimal.new("85.00")
      result = Valuation.current_value(pure_grams, price_per_gram)

      assert Decimal.eq?(result, Decimal.new("2643.80"))
    end

    test "rounds to 2 decimal places" do
      pure_grams = Decimal.new("1.0000")
      price_per_gram = Decimal.new("85.333")
      result = Valuation.current_value(pure_grams, price_per_gram)

      assert Decimal.eq?(result, Decimal.new("85.33"))
    end
  end

  describe "gain_loss/2" do
    test "calculates positive gain" do
      current = Decimal.new("3000.00")
      purchase = Decimal.new("2500.00")
      result = Valuation.gain_loss(current, purchase)

      assert Decimal.eq?(result, Decimal.new("500.00"))
    end

    test "calculates negative loss" do
      current = Decimal.new("2000.00")
      purchase = Decimal.new("2500.00")
      result = Valuation.gain_loss(current, purchase)

      assert Decimal.eq?(result, Decimal.new("-500.00"))
    end

    test "returns zero for no change" do
      amount = Decimal.new("2500.00")
      result = Valuation.gain_loss(amount, amount)

      assert Decimal.eq?(result, Decimal.new("0.00"))
    end
  end

  describe "gain_loss_percent/2" do
    test "calculates positive percentage" do
      gain = Decimal.new("500.00")
      purchase = Decimal.new("2500.00")
      result = Valuation.gain_loss_percent(gain, purchase)

      assert Decimal.eq?(result, Decimal.new("20.00"))
    end

    test "calculates negative percentage" do
      loss = Decimal.new("-500.00")
      purchase = Decimal.new("2500.00")
      result = Valuation.gain_loss_percent(loss, purchase)

      assert Decimal.eq?(result, Decimal.new("-20.00"))
    end

    test "returns nil for zero purchase price" do
      assert Valuation.gain_loss_percent(Decimal.new("100"), Decimal.new("0")) == nil
      assert Valuation.gain_loss_percent(Decimal.new("100"), 0) == nil
    end
  end

  describe "valuate_item/6" do
    test "performs complete valuation" do
      result =
        Valuation.valuate_item(
          _weight = 31.1035,
          _unit = :grams,
          _purity = 99.99,
          _quantity = 1,
          _purchase_price = 2500.00,
          _spot_price_per_gram = 85.00
        )

      assert Decimal.eq?(result.pure_gold_grams, Decimal.new("31.1004"))
      assert Decimal.eq?(result.current_value, Decimal.new("2643.53"))
      assert Decimal.eq?(result.gain_loss, Decimal.new("143.53"))
      assert Decimal.gt?(result.gain_loss_percent, Decimal.new("5"))
    end

    test "handles jewelry (18K)" do
      result =
        Valuation.valuate_item(
          _weight = 50,
          _unit = :grams,
          _purity = 75.00,
          _quantity = 1,
          _purchase_price = 5000.00,
          _spot_price_per_gram = 85.00
        )

      assert Decimal.eq?(result.pure_gold_grams, Decimal.new("37.5000"))
      assert Decimal.eq?(result.current_value, Decimal.new("3187.50"))
      assert Decimal.lt?(result.gain_loss, Decimal.new("0"))
    end
  end

  describe "aggregate_portfolio/2" do
    test "aggregates multiple items" do
      valuations = [
        %{
          pure_gold_grams: Decimal.new("31.1035"),
          current_value: Decimal.new("2643.80"),
          gain_loss: Decimal.new("143.80"),
          gain_loss_percent: Decimal.new("5.75")
        },
        %{
          pure_gold_grams: Decimal.new("15.5518"),
          current_value: Decimal.new("1321.90"),
          gain_loss: Decimal.new("-78.10"),
          gain_loss_percent: Decimal.new("-5.58")
        }
      ]

      purchase_prices = [2500.00, 1400.00]

      result = Valuation.aggregate_portfolio(valuations, purchase_prices)

      assert Decimal.eq?(result.total_pure_gold_grams, Decimal.new("46.6553"))
      assert Decimal.eq?(result.total_invested, Decimal.new("3900.00"))
      assert Decimal.eq?(result.total_current_value, Decimal.new("3965.70"))
      assert Decimal.eq?(result.total_gain_loss, Decimal.new("65.70"))
    end
  end

  describe "unit conversions" do
    test "troy_oz_to_grams" do
      result = Valuation.troy_oz_to_grams(1)
      assert Decimal.eq?(result, Decimal.new("31.1035"))
    end

    test "grams_to_troy_oz" do
      result = Valuation.grams_to_troy_oz(31.1035)
      assert Decimal.eq?(result, Decimal.new("1.0000"))
    end

    test "round-trip conversion preserves value" do
      original = Decimal.new("100.0000")
      converted = Valuation.grams_to_troy_oz(original)
      back = Valuation.troy_oz_to_grams(converted)

      diff = Decimal.abs(Decimal.sub(original, back))
      assert Decimal.lt?(diff, Decimal.new("0.001"))
    end
  end

  describe "karat_to_purity/1" do
    test "returns correct values for standard karats" do
      assert Decimal.eq?(Valuation.karat_to_purity(24), Decimal.new("99.99"))
      assert Decimal.eq?(Valuation.karat_to_purity(22), Decimal.new("91.67"))
      assert Decimal.eq?(Valuation.karat_to_purity(18), Decimal.new("75.00"))
      assert Decimal.eq?(Valuation.karat_to_purity(14), Decimal.new("58.33"))
      assert Decimal.eq?(Valuation.karat_to_purity(10), Decimal.new("41.67"))
    end

    test "calculates custom karat values" do
      result = Valuation.karat_to_purity(12)
      assert Decimal.eq?(result, Decimal.new("50.00"))
    end
  end

  # Property-based tests

  describe "property: precision invariants" do
    property "pure_gold_weight always has 4 decimal places" do
      check all(
              weight <- positive_decimal(),
              purity <- purity_percentage(),
              quantity <- positive_integer(max: 10_000)
            ) do
        result = Valuation.pure_gold_weight(weight, :grams, purity, quantity)

        decimal_places = count_decimal_places(result)
        assert decimal_places <= 4
      end
    end

    property "current_value always has 2 decimal places" do
      check all(
              grams <- positive_decimal(),
              price <- positive_decimal()
            ) do
        result = Valuation.current_value(grams, price)

        decimal_places = count_decimal_places(result)
        assert decimal_places <= 2
      end
    end

    property "gain_loss_percent returns nil only for zero purchase price" do
      check all(
              gain <- decimal_gen(),
              purchase <- positive_decimal()
            ) do
        result = Valuation.gain_loss_percent(gain, purchase)
        assert result != nil
      end
    end
  end

  describe "property: mathematical consistency" do
    property "pure_gold_weight scales linearly with quantity" do
      check all(
              weight <- positive_decimal(),
              purity <- purity_percentage(),
              q1 <- positive_integer(max: 100),
              q2 <- positive_integer(max: 100)
            ) do
        result1 = Valuation.pure_gold_weight(weight, :grams, purity, q1)
        result2 = Valuation.pure_gold_weight(weight, :grams, purity, q2)

        ratio1 = Decimal.div(result1, Decimal.new(q1))
        ratio2 = Decimal.div(result2, Decimal.new(q2))

        diff = Decimal.abs(Decimal.sub(ratio1, ratio2))
        assert Decimal.lt?(diff, Decimal.new("0.0001"))
      end
    end

    property "gain_loss = current_value - purchase_price" do
      check all(
              current <- positive_decimal(),
              purchase <- positive_decimal()
            ) do
        current_rounded = Decimal.round(current, 2)
        purchase_rounded = Decimal.round(purchase, 2)

        gl = Valuation.gain_loss(current_rounded, purchase_rounded)
        expected = Decimal.sub(current_rounded, purchase_rounded) |> Decimal.round(2)

        assert Decimal.eq?(gl, expected)
      end
    end

    property "valuate_item produces consistent gain_loss" do
      check all(
              weight <- positive_decimal(),
              purity <- purity_percentage(),
              quantity <- positive_integer(max: 100),
              purchase <- positive_decimal(),
              spot <- positive_decimal()
            ) do
        result = Valuation.valuate_item(weight, :grams, purity, quantity, purchase, spot)

        expected_gl = Decimal.sub(result.current_value, Decimal.round(Decimal.new(to_string(purchase)), 2))
        diff = Decimal.abs(Decimal.sub(result.gain_loss, Decimal.round(expected_gl, 2)))

        assert Decimal.lte?(diff, Decimal.new("0.01"))
      end
    end
  end

  describe "property: edge cases" do
    property "tiny weights don't cause precision loss or errors" do
      check all(weight <- tiny_decimal()) do
        result = Valuation.pure_gold_weight(weight, :grams, 99.99, 1)
        assert %Decimal{} = result
        assert Decimal.gte?(result, Decimal.new("0"))
      end
    end

    property "large quantities don't overflow" do
      check all(
              weight <- positive_decimal(),
              quantity <- integer(1_000..1_000_000)
            ) do
        result = Valuation.pure_gold_weight(weight, :grams, 99.99, quantity)
        assert %Decimal{} = result
        assert Decimal.gt?(result, Decimal.new("0"))
      end
    end

    property "round-trip unit conversion is stable" do
      check all(grams <- positive_decimal()) do
        troy_oz = Valuation.grams_to_troy_oz(grams)
        back_to_grams = Valuation.troy_oz_to_grams(troy_oz)

        original = Decimal.round(Decimal.new(to_string(grams)), 4)
        diff = Decimal.abs(Decimal.sub(original, back_to_grams))

        assert Decimal.lt?(diff, Decimal.new("0.01"))
      end
    end

    property "high precision inputs don't cause errors" do
      check all(
              weight <- StreamData.float(min: 0.000001, max: 1000.0),
              price <- StreamData.float(min: 0.01, max: 10_000.0)
            ) do
        result = Valuation.current_value(Decimal.from_float(weight), Decimal.from_float(price))
        assert %Decimal{} = result
      end
    end
  end

  # Custom generators

  defp positive_decimal do
    StreamData.float(min: 0.0001, max: 10_000.0)
    |> StreamData.map(&Decimal.from_float/1)
  end

  defp tiny_decimal do
    StreamData.float(min: 0.000001, max: 0.001)
    |> StreamData.map(&Decimal.from_float/1)
  end

  defp purity_percentage do
    StreamData.float(min: 1.0, max: 100.0)
    |> StreamData.map(&Decimal.from_float/1)
  end

  defp decimal_gen do
    StreamData.float(min: -10_000.0, max: 10_000.0)
    |> StreamData.map(&Decimal.from_float/1)
  end

  defp positive_integer(opts) do
    max = Keyword.get(opts, :max, 1000)
    StreamData.integer(1..max)
  end

  defp count_decimal_places(%Decimal{} = d) do
    str = Decimal.to_string(d)

    case String.split(str, ".") do
      [_integer] -> 0
      [_integer, decimal] -> String.length(decimal)
    end
  end
end
