defmodule Aurum.Gold.PriceClient do
  @moduledoc """
  Fetches gold spot prices from the free fawazahmed0/exchange-api.

  Uses two endpoints with automatic fallback:
  1. Primary: cdn.jsdelivr.net (CDN)
  2. Fallback: currency-api.pages.dev (Cloudflare)

  No API keys required. No rate limits. Daily updated.
  All prices are returned in Indonesian Rupiah (IDR).
  """

  require Logger

  @timeout 10_000
  @grams_per_oz Decimal.new("31.1035")

  @primary_url "https://cdn.jsdelivr.net/npm/@fawazahmed0/currency-api@latest/v1/currencies/xau.min.json"
  @fallback_url "https://latest.currency-api.pages.dev/v1/currencies/xau.min.json"

  @type price_result :: {:ok, price_data()} | {:error, error_reason()}
  @type price_data :: %{
          price_per_oz: Decimal.t(),
          price_per_gram: Decimal.t(),
          currency: String.t(),
          timestamp: DateTime.t(),
          source: atom(),
          response_time_ms: non_neg_integer()
        }
  @type error_reason ::
          :timeout
          | :invalid_response
          | {:http_error, integer()}
          | {:network_error, term()}

  @doc """
  Fetches gold price from exchange-api via CDN (primary).
  Returns XAU/IDR spot price in Indonesian Rupiah.
  """
  @spec fetch_primary() :: price_result()
  def fetch_primary do
    perform_request(
      :exchange_api,
      fn -> Req.get(@primary_url, receive_timeout: @timeout) end,
      &validate_response/1,
      %{}
    )
  end

  @doc """
  Fetches gold price from exchange-api via Cloudflare (fallback).
  Returns XAU/IDR spot price in Indonesian Rupiah.
  """
  @spec fetch_fallback() :: price_result()
  def fetch_fallback do
    perform_request(
      :exchange_api_fallback,
      fn -> Req.get(@fallback_url, receive_timeout: @timeout) end,
      &validate_response/1,
      %{}
    )
  end

  # Generic request handler that reduces duplication across providers
  defp perform_request(source, req_fn, validator, status_map) do
    start_time = System.monotonic_time(:millisecond)

    case req_fn.() do
      {:ok, %Req.Response{status: 200, body: body}} ->
        response_time = System.monotonic_time(:millisecond) - start_time

        case validator.(body) do
          {:ok, price_data} ->
            log_success(source, response_time, price_data)
            {:ok, Map.put(price_data, :response_time_ms, response_time)}

          {:error, reason} ->
            log_failure(source, reason, body)
            {:error, reason}
        end

      {:ok, %Req.Response{status: status, body: body}} ->
        reason = Map.get(status_map, status, {:http_error, status})
        log_failure(source, reason, body)
        {:error, reason}

      {:error, %Req.TransportError{reason: :timeout}} ->
        log_failure(source, :timeout, nil)
        {:error, :timeout}

      {:error, reason} ->
        log_failure(source, reason, nil)
        {:error, {:network_error, reason}}
    end
  end

  @doc """
  Fetches gold price from all configured providers and returns results.
  Useful for comparing reliability and response times.
  """
  @spec fetch_all() :: %{atom() => price_result()}
  def fetch_all do
    tasks = [
      Task.async(fn -> {:exchange_api, fetch_primary()} end),
      Task.async(fn -> {:exchange_api_fallback, fetch_fallback()} end)
    ]

    tasks
    |> Task.await_many(@timeout + 1000)
    |> Map.new()
  end

  @doc """
  Fetches gold price with fallback logic.
  Tries CDN first, then Cloudflare fallback.
  """
  @spec fetch_with_fallback() :: price_result()
  def fetch_with_fallback do
    providers = [
      &fetch_primary/0,
      &fetch_fallback/0
    ]

    Enum.reduce_while(providers, {:error, :all_providers_failed}, fn fetch_fn, _acc ->
      case fetch_fn.() do
        {:ok, _} = success -> {:halt, success}
        {:error, _} -> {:cont, {:error, :all_providers_failed}}
      end
    end)
  end

  # Response validator

  defp validate_response(%{"date" => date_str, "xau" => %{"idr" => idr_rate}})
       when is_number(idr_rate) and idr_rate > 0 do
    timestamp =
      case Date.from_iso8601(date_str) do
        {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
        _ -> DateTime.utc_now()
      end

    price_per_oz = Decimal.new(to_string(idr_rate))
    price_per_gram = Decimal.div(price_per_oz, @grams_per_oz)

    {:ok,
     %{
       price_per_oz: price_per_oz,
       price_per_gram: price_per_gram,
       currency: "IDR",
       timestamp: timestamp,
       source: :exchange_api
     }}
  end

  defp validate_response(_), do: {:error, :invalid_response}

  # Logging helpers

  defp log_success(source, response_time, price_data) do
    Logger.info(
      "[PriceClient] #{source} success | " <>
        "price_per_oz=#{price_data.price_per_oz} #{price_data.currency} | " <>
        "response_time=#{response_time}ms"
    )
  end

  defp log_failure(source, reason, body) do
    Logger.warning(
      "[PriceClient] #{source} failed | reason=#{inspect(reason)} | body=#{inspect(body)}"
    )
  end
end
