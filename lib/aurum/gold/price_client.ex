defmodule Aurum.Gold.PriceClient do
  @moduledoc """
  Fetches gold spot prices from multiple API providers.
  Validates response schemas and logs response times/failures for reliability testing.

  Candidate APIs:
  1. GoldAPI.io - Free tier (100 req/month), requires API key, supports IDR
  2. MetalpriceAPI - Free tier, requires API key, supports IDR

  All prices are returned in Indonesian Rupiah (IDR).
  """

  require Logger

  @timeout 10_000
  @grams_per_oz Decimal.new("31.1035")

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
          | :missing_api_key
          | :unauthorized
          | :rate_limited
          | {:http_error, integer()}
          | {:network_error, term()}

  @doc """
  Fetches gold price from GoldAPI.io.
  Requires API key set in config or environment variable GOLDAPI_KEY.

  Free tier: 100 requests/month
  Returns XAU/IDR spot price in Indonesian Rupiah.
  """
  @spec fetch_goldapi() :: price_result()
  def fetch_goldapi do
    with {:ok, api_key} <- require_api_key(:goldapi_key, "GOLDAPI_KEY") do
      perform_request(
        :goldapi,
        fn ->
          Req.get("https://www.goldapi.io/api/XAU/IDR",
            headers: [{"x-access-token", api_key}],
            receive_timeout: @timeout
          )
        end,
        &validate_goldapi_response/1,
        %{401 => :unauthorized, 429 => :rate_limited}
      )
    end
  end

  @doc """
  Fetches gold price from MetalpriceAPI.
  Requires API key set in config or environment variable METALPRICEAPI_KEY.

  Free tier available with registration.
  Returns XAU/IDR spot price in Indonesian Rupiah.
  """
  @spec fetch_metalpriceapi() :: price_result()
  def fetch_metalpriceapi do
    with {:ok, api_key} <- require_api_key(:metalpriceapi_key, "METALPRICEAPI_KEY") do
      url = "https://api.metalpriceapi.com/v1/latest?api_key=#{api_key}&base=IDR&currencies=XAU"

      perform_request(
        :metalpriceapi,
        fn -> Req.get(url, receive_timeout: @timeout) end,
        &validate_metalpriceapi_response/1,
        %{401 => :unauthorized}
      )
    end
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

  defp require_api_key(config_key, env_var) do
    case Application.get_env(:aurum, config_key) || System.get_env(env_var) do
      nil -> {:error, :missing_api_key}
      "" -> {:error, :missing_api_key}
      key -> {:ok, key}
    end
  end

  @doc """
  Fetches gold price from all configured providers and returns results.
  Useful for comparing reliability and response times.
  """
  @spec fetch_all() :: %{atom() => price_result()}
  def fetch_all do
    tasks = [
      Task.async(fn -> {:goldapi, fetch_goldapi()} end),
      Task.async(fn -> {:metalpriceapi, fetch_metalpriceapi()} end)
    ]

    tasks
    |> Task.await_many(@timeout + 1000)
    |> Map.new()
  end

  @doc """
  Fetches gold price with fallback logic.
  Tries providers in order until one succeeds.
  Priority: GoldAPI (most accurate) -> MetalpriceAPI
  """
  @spec fetch_with_fallback() :: price_result()
  def fetch_with_fallback do
    providers = [
      &fetch_goldapi/0,
      &fetch_metalpriceapi/0
    ]

    Enum.reduce_while(providers, {:error, :all_providers_failed}, fn fetch_fn, _acc ->
      case fetch_fn.() do
        {:ok, _} = success -> {:halt, success}
        {:error, :missing_api_key} -> {:cont, {:error, :all_providers_failed}}
        {:error, _} -> {:cont, {:error, :all_providers_failed}}
      end
    end)
  end

  # Response validators

  defp validate_goldapi_response(%{"price" => price, "timestamp" => timestamp})
       when is_number(price) and is_integer(timestamp) do
    with {:ok, dt} <- DateTime.from_unix(timestamp) do
      price_per_oz = Decimal.new(to_string(price))
      price_per_gram = Decimal.div(price_per_oz, @grams_per_oz)

      {:ok,
       %{
         price_per_oz: price_per_oz,
         price_per_gram: price_per_gram,
         currency: "IDR",
         timestamp: dt,
         source: :goldapi
       }}
    else
      _ -> {:error, :invalid_response}
    end
  end

  defp validate_goldapi_response(_), do: {:error, :invalid_response}

  defp validate_metalpriceapi_response(%{
         "success" => true,
         "rates" => %{"XAU" => rate},
         "timestamp" => timestamp
       })
       when is_number(rate) and rate > 0 and is_integer(timestamp) do
    with {:ok, dt} <- DateTime.from_unix(timestamp) do
      price_per_oz = Decimal.div(Decimal.new("1"), Decimal.new(to_string(rate)))
      price_per_gram = Decimal.div(price_per_oz, @grams_per_oz)

      {:ok,
       %{
         price_per_oz: price_per_oz,
         price_per_gram: price_per_gram,
         currency: "IDR",
         timestamp: dt,
         source: :metalpriceapi
       }}
    else
      _ -> {:error, :invalid_response}
    end
  end

  defp validate_metalpriceapi_response(_), do: {:error, :invalid_response}

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
