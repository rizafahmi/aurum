defmodule Aurum.UnitsTest do
  use ExUnit.Case, async: true
  use ExUnitProperties

  alias Aurum.Units

  @troy_oz_in_grams Decimal.new("31.1035")

  describe "basic conversions" do
    test "troy_oz_to_grams converts correctly" do
      assert Decimal.eq?(Units.troy_oz_to_grams(1), @troy_oz_in_grams)
      assert Decimal.eq?(Units.troy_oz_to_grams(2), Decimal.new("62.2070"))
      assert Decimal.eq?(Units.troy_oz_to_grams(0.5), Decimal.new("15.5518"))
    end

    test "grams_to_troy_oz converts correctly" do
      assert Decimal.eq?(Units.grams_to_troy_oz(31.1035), Decimal.new("1.0000"))
      assert Decimal.eq?(Units.grams_to_troy_oz(62.207), Decimal.new("2.0000"))
    end

    test "to_canonical_grams with grams returns rounded value" do
      result = Units.to_canonical_grams(100.123456, :grams)
      assert Decimal.eq?(result, Decimal.new("100.1235"))
    end

    test "to_canonical_grams with troy_oz converts to grams" do
      result = Units.to_canonical_grams(1, :troy_oz)
      assert Decimal.eq?(result, @troy_oz_in_grams)
    end

    test "from_canonical_grams with grams returns same value" do
      grams = Decimal.new("100.0000")
      result = Units.from_canonical_grams(grams, :grams)
      assert Decimal.eq?(result, grams)
    end

    test "from_canonical_grams with troy_oz converts from grams" do
      grams = Decimal.new("31.1035")
      result = Units.from_canonical_grams(grams, :troy_oz)
      assert Decimal.eq?(result, Decimal.new("1.0000"))
    end
  end

  describe "weight_input struct" do
    test "create_weight_input preserves original value and unit" do
      input = Units.create_weight_input(1, :troy_oz)

      assert Decimal.eq?(input.value, Decimal.new("1.0000"))
      assert input.unit == :troy_oz
      assert Decimal.eq?(input.canonical_grams, @troy_oz_in_grams)
    end

    test "create_weight_input with grams" do
      input = Units.create_weight_input(100, :grams)

      assert Decimal.eq?(input.value, Decimal.new("100.0000"))
      assert input.unit == :grams
      assert Decimal.eq?(input.canonical_grams, Decimal.new("100.0000"))
    end

    test "restore_weight_input recreates original input from DB data" do
      canonical = Decimal.new("31.1035")
      original_unit = :troy_oz

      restored = Units.restore_weight_input(canonical, original_unit)

      assert Decimal.eq?(restored.value, Decimal.new("1.0000"))
      assert restored.unit == :troy_oz
      assert Decimal.eq?(restored.canonical_grams, canonical)
    end

    test "update_weight_value recalculates canonical grams" do
      input = Units.create_weight_input(1, :troy_oz)
      updated = Units.update_weight_value(input, 2)

      assert Decimal.eq?(updated.value, Decimal.new("2.0000"))
      assert updated.unit == :troy_oz
      assert Decimal.eq?(updated.canonical_grams, Decimal.new("62.2070"))
    end

    test "update_weight_unit converts value while preserving physical amount" do
      input = Units.create_weight_input(1, :troy_oz)
      updated = Units.update_weight_unit(input, :grams)

      assert Decimal.eq?(updated.value, @troy_oz_in_grams)
      assert updated.unit == :grams
      assert Decimal.eq?(updated.canonical_grams, input.canonical_grams)
    end
  end

  describe "round-trip edit scenarios" do
    test "scenario: user enters 1 troy oz, edits display, saves correctly" do
      input = Units.create_weight_input(1, :troy_oz)
      assert Decimal.eq?(input.canonical_grams, Decimal.new("31.1035"))

      db_grams = input.canonical_grams
      db_unit = input.unit

      restored = Units.restore_weight_input(db_grams, db_unit)
      assert Decimal.eq?(restored.value, Decimal.new("1.0000"))
      assert restored.unit == :troy_oz

      edited = Units.update_weight_value(restored, 1.5)
      assert Decimal.eq?(edited.canonical_grams, Decimal.new("46.6553"))

      final_restored = Units.restore_weight_input(edited.canonical_grams, edited.unit)
      assert Decimal.eq?(final_restored.value, Decimal.new("1.5000"))
    end

    test "scenario: user switches unit from troy oz to grams mid-edit" do
      input = Units.create_weight_input(1, :troy_oz)
      assert Decimal.eq?(input.canonical_grams, Decimal.new("31.1035"))

      switched = Units.update_weight_unit(input, :grams)
      assert Decimal.eq?(switched.value, Decimal.new("31.1035"))
      assert switched.unit == :grams
      assert Decimal.eq?(switched.canonical_grams, Decimal.new("31.1035"))

      edited = Units.update_weight_value(switched, 35)
      assert Decimal.eq?(edited.canonical_grams, Decimal.new("35.0000"))

      db_grams = edited.canonical_grams
      db_unit = edited.unit
      restored = Units.restore_weight_input(db_grams, db_unit)

      assert Decimal.eq?(restored.value, Decimal.new("35.0000"))
      assert restored.unit == :grams
    end

    test "scenario: user enters grams, switches to troy oz, edits, saves" do
      input = Units.create_weight_input(100, :grams)
      assert Decimal.eq?(input.canonical_grams, Decimal.new("100.0000"))

      switched = Units.update_weight_unit(input, :troy_oz)
      assert Decimal.eq?(switched.value, Decimal.new("3.2151"))
      assert Decimal.eq?(switched.canonical_grams, Decimal.new("100.0000"))

      edited = Units.update_weight_value(switched, 3)
      expected_grams = Units.troy_oz_to_grams(3)
      assert Decimal.eq?(edited.canonical_grams, expected_grams)

      restored = Units.restore_weight_input(edited.canonical_grams, edited.unit)
      assert Decimal.eq?(restored.value, Decimal.new("3.0000"))
    end

    test "scenario: prevent double conversion bug" do
      input = Units.create_weight_input(1, :troy_oz)
      canonical = input.canonical_grams

      restored1 = Units.restore_weight_input(canonical, :troy_oz)
      restored2 = Units.restore_weight_input(canonical, :troy_oz)
      restored3 = Units.restore_weight_input(canonical, :troy_oz)

      assert Decimal.eq?(restored1.value, Decimal.new("1.0000"))
      assert Decimal.eq?(restored2.value, Decimal.new("1.0000"))
      assert Decimal.eq?(restored3.value, Decimal.new("1.0000"))
      assert Decimal.eq?(restored3.canonical_grams, canonical)
    end

    test "scenario: multiple edits preserve precision" do
      input = Units.create_weight_input(1, :troy_oz)

      edited1 = Units.update_weight_value(input, 1.1)
      edited2 = Units.update_weight_value(edited1, 1.2)
      edited3 = Units.update_weight_value(edited2, 1.3)

      final = Units.restore_weight_input(edited3.canonical_grams, edited3.unit)
      assert Decimal.eq?(final.value, Decimal.new("1.3000"))
    end
  end

  describe "validation and parsing" do
    test "valid_weight? returns true for positive values" do
      assert Units.valid_weight?(1) == true
      assert Units.valid_weight?(0.001) == true
      assert Units.valid_weight?(Decimal.new("100")) == true
    end

    test "valid_weight? returns false for zero or negative" do
      assert Units.valid_weight?(0) == false
      assert Units.valid_weight?(-1) == false
      assert Units.valid_weight?(Decimal.new("0")) == false
    end

    test "parse_unit handles valid inputs" do
      assert Units.parse_unit("grams") == {:ok, :grams}
      assert Units.parse_unit("g") == {:ok, :grams}
      assert Units.parse_unit("troy_oz") == {:ok, :troy_oz}
      assert Units.parse_unit("oz") == {:ok, :troy_oz}
      assert Units.parse_unit("toz") == {:ok, :troy_oz}
    end

    test "parse_unit rejects invalid inputs" do
      assert Units.parse_unit("kilograms") == {:error, :invalid_unit}
      assert Units.parse_unit("pounds") == {:error, :invalid_unit}
      assert Units.parse_unit("") == {:error, :invalid_unit}
    end

    test "unit_label returns short form" do
      assert Units.unit_label(:grams) == "g"
      assert Units.unit_label(:troy_oz) == "oz"
    end

    test "unit_name returns full name" do
      assert Units.unit_name(:grams) == "grams"
      assert Units.unit_name(:troy_oz) == "troy ounces"
    end
  end

  describe "property: round-trip stability" do
    property "grams -> troy_oz -> grams is stable" do
      check all(grams <- positive_weight()) do
        original = Decimal.round(Decimal.new(to_string(grams)), 4)
        troy_oz = Units.grams_to_troy_oz(original)
        back = Units.troy_oz_to_grams(troy_oz)

        diff = Decimal.abs(Decimal.sub(original, back))
        assert Decimal.lte?(diff, Decimal.new("0.002"))
      end
    end

    property "troy_oz -> grams -> troy_oz is stable" do
      check all(troy_oz <- positive_weight()) do
        original = Decimal.round(Decimal.new(to_string(troy_oz)), 4)
        grams = Units.troy_oz_to_grams(original)
        back = Units.grams_to_troy_oz(grams)

        diff = Decimal.abs(Decimal.sub(original, back))
        assert Decimal.lt?(diff, Decimal.new("0.0001"))
      end
    end

    property "create -> store -> restore preserves value" do
      check all(
              value <- positive_weight(),
              unit <- unit_gen()
            ) do
        input = Units.create_weight_input(value, unit)

        db_grams = input.canonical_grams
        db_unit = input.unit

        restored = Units.restore_weight_input(db_grams, db_unit)

        original_value = Decimal.round(Decimal.new(to_string(value)), 4)
        diff = Decimal.abs(Decimal.sub(original_value, restored.value))
        assert Decimal.lte?(diff, Decimal.new("0.0002"))
        assert restored.unit == unit
      end
    end

    property "unit switch preserves canonical grams" do
      check all(
              value <- positive_weight(),
              unit1 <- unit_gen(),
              unit2 <- unit_gen()
            ) do
        input = Units.create_weight_input(value, unit1)
        switched = Units.update_weight_unit(input, unit2)

        assert Decimal.eq?(input.canonical_grams, switched.canonical_grams)
      end
    end

    property "canonical grams is always positive for positive input" do
      check all(
              value <- positive_weight(),
              unit <- unit_gen()
            ) do
        input = Units.create_weight_input(value, unit)
        assert Decimal.gt?(input.canonical_grams, Decimal.new("0"))
      end
    end
  end

  describe "property: precision limits" do
    property "all conversions have max 4 decimal places" do
      check all(value <- positive_weight()) do
        grams = Units.troy_oz_to_grams(value)
        troy_oz = Units.grams_to_troy_oz(value)

        assert decimal_places(grams) <= 4
        assert decimal_places(troy_oz) <= 4
      end
    end
  end

  describe "edge cases" do
    test "tiny weight conversion" do
      tiny = Decimal.new("0.0001")
      result = Units.troy_oz_to_grams(tiny)
      assert Decimal.gt?(result, Decimal.new("0"))
    end

    test "large weight conversion" do
      large = Decimal.new("1000000")
      result = Units.troy_oz_to_grams(large)
      assert Decimal.gt?(result, large)
    end

    test "handles Decimal input" do
      dec = Decimal.new("1.5")
      result = Units.troy_oz_to_grams(dec)
      assert Decimal.eq?(result, Decimal.new("46.6553"))
    end

    test "handles float input" do
      result = Units.troy_oz_to_grams(1.5)
      assert Decimal.eq?(result, Decimal.new("46.6553"))
    end

    test "handles integer input" do
      result = Units.troy_oz_to_grams(2)
      assert Decimal.eq?(result, Decimal.new("62.2070"))
    end

    test "handles string input" do
      result = Units.troy_oz_to_grams("1.5")
      assert Decimal.eq?(result, Decimal.new("46.6553"))
    end
  end

  # Generators

  defp positive_weight do
    StreamData.float(min: 0.0001, max: 10_000.0)
  end

  defp unit_gen do
    StreamData.member_of([:grams, :troy_oz])
  end

  defp decimal_places(%Decimal{} = d) do
    str = Decimal.to_string(d)

    case String.split(str, ".") do
      [_integer] -> 0
      [_integer, decimal] -> String.length(decimal)
    end
  end
end
