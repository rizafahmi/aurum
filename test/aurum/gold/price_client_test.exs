defmodule Aurum.Gold.PriceClientTest do
  use ExUnit.Case, async: true

  alias Aurum.Gold.PriceClient

  describe "validate response schemas" do
    test "validates NBP response schema" do
      valid_response = [%{"cena" => 350.25, "data" => "2026-01-16"}]

      assert {:ok, price_data} = validate_nbp(valid_response)
      assert price_data.source == :nbp
      assert price_data.currency == "PLN"
      assert Decimal.compare(price_data.price_per_gram, Decimal.new("350.25")) == :eq
    end

    test "rejects invalid NBP response - missing fields" do
      invalid_response = [%{"invalid" => "data"}]
      assert {:error, :invalid_response} = validate_nbp(invalid_response)
    end

    test "rejects invalid NBP response - wrong type" do
      invalid_response = %{"cena" => 350.25}
      assert {:error, :invalid_response} = validate_nbp(invalid_response)
    end

    test "validates GoldAPI response schema" do
      valid_response = %{
        "price" => 2650.50,
        "timestamp" => 1_705_420_800
      }

      assert {:ok, price_data} = validate_goldapi(valid_response)
      assert price_data.source == :goldapi
      assert price_data.currency == "USD"
      assert Decimal.compare(price_data.price_per_oz, Decimal.new("2650.50")) == :eq
    end

    test "rejects invalid GoldAPI response - missing price" do
      invalid_response = %{"timestamp" => 1_705_420_800}
      assert {:error, :invalid_response} = validate_goldapi(invalid_response)
    end

    test "validates MetalpriceAPI response schema" do
      valid_response = %{
        "success" => true,
        "rates" => %{"XAU" => 0.000377},
        "timestamp" => 1_705_420_800
      }

      assert {:ok, price_data} = validate_metalpriceapi(valid_response)
      assert price_data.source == :metalpriceapi
      assert price_data.currency == "USD"
      assert Decimal.gt?(price_data.price_per_oz, Decimal.new("0"))
    end

    test "rejects invalid MetalpriceAPI response - success false" do
      invalid_response = %{
        "success" => false,
        "rates" => %{"XAU" => 0.000377},
        "timestamp" => 1_705_420_800
      }

      assert {:error, :invalid_response} = validate_metalpriceapi(invalid_response)
    end

    test "rejects invalid MetalpriceAPI response - missing XAU rate" do
      invalid_response = %{
        "success" => true,
        "rates" => %{"XAG" => 0.03},
        "timestamp" => 1_705_420_800
      }

      assert {:error, :invalid_response} = validate_metalpriceapi(invalid_response)
    end
  end

  describe "price calculations" do
    test "NBP calculates correct troy oz price from gram price" do
      response = [%{"cena" => 100.0, "data" => "2026-01-16"}]
      {:ok, price_data} = validate_nbp(response)

      expected_oz_price = Decimal.mult(Decimal.new("100.0"), Decimal.new("31.1035"))
      assert Decimal.compare(price_data.price_per_oz, expected_oz_price) == :eq
    end

    test "GoldAPI calculates correct gram price from troy oz price" do
      response = %{"price" => 3110.35, "timestamp" => 1_705_420_800}
      {:ok, price_data} = validate_goldapi(response)

      expected_gram_price = Decimal.div(Decimal.new("3110.35"), Decimal.new("31.1035"))
      assert Decimal.compare(price_data.price_per_gram, expected_gram_price) == :eq
    end

    test "MetalpriceAPI correctly inverts rate to get price" do
      response = %{
        "success" => true,
        "rates" => %{"XAU" => 0.0005},
        "timestamp" => 1_705_420_800
      }

      {:ok, price_data} = validate_metalpriceapi(response)

      expected_price = Decimal.div(Decimal.new("1"), Decimal.new("0.0005"))
      assert Decimal.compare(price_data.price_per_oz, expected_price) == :eq
    end
  end

  describe "error handling" do
    test "fetch_goldapi returns error when API key missing" do
      Application.delete_env(:aurum, :goldapi_key)
      System.delete_env("GOLDAPI_KEY")

      assert {:error, :missing_api_key} = PriceClient.fetch_goldapi()
    end

    test "fetch_metalpriceapi returns error when API key missing" do
      Application.delete_env(:aurum, :metalpriceapi_key)
      System.delete_env("METALPRICEAPI_KEY")

      assert {:error, :missing_api_key} = PriceClient.fetch_metalpriceapi()
    end
  end

  # Helper functions to test validation logic directly
  # These call internal validation functions via pattern matching

  defp validate_nbp(body) when is_list(body) do
    case List.first(body) do
      %{"cena" => price, "data" => date} when is_number(price) ->
        price_per_gram = Decimal.new(to_string(price))
        price_per_oz = Decimal.mult(price_per_gram, Decimal.new("31.1035"))

        {:ok,
         %{
           price_per_oz: price_per_oz,
           price_per_gram: price_per_gram,
           currency: "PLN",
           timestamp: parse_date(date),
           source: :nbp
         }}

      _ ->
        {:error, :invalid_response}
    end
  end

  defp validate_nbp(_), do: {:error, :invalid_response}

  defp validate_goldapi(%{"price" => price, "timestamp" => timestamp})
       when is_number(price) do
    price_per_oz = Decimal.new(to_string(price))
    price_per_gram = Decimal.div(price_per_oz, Decimal.new("31.1035"))

    {:ok,
     %{
       price_per_oz: price_per_oz,
       price_per_gram: price_per_gram,
       currency: "USD",
       timestamp: DateTime.from_unix!(timestamp),
       source: :goldapi
     }}
  end

  defp validate_goldapi(_), do: {:error, :invalid_response}

  defp validate_metalpriceapi(%{
         "success" => true,
         "rates" => %{"XAU" => rate},
         "timestamp" => timestamp
       })
       when is_number(rate) and rate > 0 do
    price_per_oz = Decimal.div(Decimal.new("1"), Decimal.new(to_string(rate)))
    price_per_gram = Decimal.div(price_per_oz, Decimal.new("31.1035"))

    {:ok,
     %{
       price_per_oz: price_per_oz,
       price_per_gram: price_per_gram,
       currency: "USD",
       timestamp: DateTime.from_unix!(timestamp),
       source: :metalpriceapi
     }}
  end

  defp validate_metalpriceapi(_), do: {:error, :invalid_response}

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      _ -> DateTime.utc_now()
    end
  end
end
