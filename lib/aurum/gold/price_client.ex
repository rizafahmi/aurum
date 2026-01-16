defmodule Aurum.Gold.PriceClient do
  @moduledoc """
  Fetches gold spot prices from multiple API providers.
  Validates response schemas and logs response times/failures for reliability testing.

  Candidate APIs:
  1. NBP Web API (Polish National Bank) - Free, no auth, returns gold price in PLN per gram
  2. GoldAPI.io - Free tier (100 req/month), requires API key
  3. MetalpriceAPI - Free tier, requires API key

  For MVP validation, we test all providers and track reliability metrics.
  """

  require Logger

  @timeout 10_000

  @type price_result :: {:ok, price_data()} | {:error, error_reason()}
  @type price_data :: %{
          price_per_oz: Decimal.t(),
          price_per_gram: Decimal.t(),
          currency: String.t(),
          timestamp: DateTime.t(),
          source: atom(),
          response_time_ms: non_neg_integer()
        }
  @type error_reason :: :timeout | :invalid_response | :api_error | :network_error | term()

  @doc """
  Fetches gold price from NBP (Polish National Bank) API.
  Returns price in PLN per gram - requires USD/PLN conversion for XAU/USD.

  Note: NBP provides gold price in PLN per gram, updated daily.
  This is a truly free API with no authentication required.
  """
  @spec fetch_nbp() :: price_result()
  def fetch_nbp do
    url = "http://api.nbp.pl/api/cenyzlota?format=json"
    start_time = System.monotonic_time(:millisecond)

    case Req.get(url, receive_timeout: @timeout) do
      {:ok, %Req.Response{status: 200, body: body}} ->
        end_time = System.monotonic_time(:millisecond)
        response_time = end_time - start_time

        case validate_nbp_response(body) do
          {:ok, price_data} ->
            log_success(:nbp, response_time, price_data)
            {:ok, Map.put(price_data, :response_time_ms, response_time)}

          {:error, reason} ->
            log_failure(:nbp, reason, body)
            {:error, reason}
        end

      {:ok, %Req.Response{status: status}} ->
        log_failure(:nbp, {:http_error, status}, nil)
        {:error, {:http_error, status}}

      {:error, %Req.TransportError{reason: :timeout}} ->
        log_failure(:nbp, :timeout, nil)
        {:error, :timeout}

      {:error, reason} ->
        log_failure(:nbp, reason, nil)
        {:error, :network_error}
    end
  end

  @doc """
  Fetches gold price from GoldAPI.io.
  Requires API key set in config or environment variable GOLDAPI_KEY.

  Free tier: 100 requests/month
  Returns XAU/USD spot price.
  """
  @spec fetch_goldapi() :: price_result()
  def fetch_goldapi do
    api_key = Application.get_env(:aurum, :goldapi_key) || System.get_env("GOLDAPI_KEY")

    if is_nil(api_key) or api_key == "" do
      {:error, :missing_api_key}
    else
      do_fetch_goldapi(api_key)
    end
  end

  defp do_fetch_goldapi(api_key) do
    url = "https://www.goldapi.io/api/XAU/USD"
    start_time = System.monotonic_time(:millisecond)

    result =
      Req.get(url,
        headers: [{"x-access-token", api_key}],
        receive_timeout: @timeout
      )

    handle_goldapi_response(result, start_time)
  end

  defp handle_goldapi_response({:ok, %Req.Response{status: 200, body: body}}, start_time) do
    response_time = System.monotonic_time(:millisecond) - start_time

    case validate_goldapi_response(body) do
      {:ok, price_data} ->
        log_success(:goldapi, response_time, price_data)
        {:ok, Map.put(price_data, :response_time_ms, response_time)}

      {:error, reason} ->
        log_failure(:goldapi, reason, body)
        {:error, reason}
    end
  end

  defp handle_goldapi_response({:ok, %Req.Response{status: 401}}, _start_time) do
    log_failure(:goldapi, :unauthorized, nil)
    {:error, :unauthorized}
  end

  defp handle_goldapi_response({:ok, %Req.Response{status: 429}}, _start_time) do
    log_failure(:goldapi, :rate_limited, nil)
    {:error, :rate_limited}
  end

  defp handle_goldapi_response({:ok, %Req.Response{status: status}}, _start_time) do
    log_failure(:goldapi, {:http_error, status}, nil)
    {:error, {:http_error, status}}
  end

  defp handle_goldapi_response({:error, %Req.TransportError{reason: :timeout}}, _start_time) do
    log_failure(:goldapi, :timeout, nil)
    {:error, :timeout}
  end

  defp handle_goldapi_response({:error, reason}, _start_time) do
    log_failure(:goldapi, reason, nil)
    {:error, :network_error}
  end

  @doc """
  Fetches gold price from MetalpriceAPI.
  Requires API key set in config or environment variable METALPRICEAPI_KEY.

  Free tier available with registration.
  Returns XAU/USD spot price.
  """
  @spec fetch_metalpriceapi() :: price_result()
  def fetch_metalpriceapi do
    api_key = Application.get_env(:aurum, :metalpriceapi_key) || System.get_env("METALPRICEAPI_KEY")

    if is_nil(api_key) or api_key == "" do
      {:error, :missing_api_key}
    else
      do_fetch_metalpriceapi(api_key)
    end
  end

  defp do_fetch_metalpriceapi(api_key) do
    url = "https://api.metalpriceapi.com/v1/latest?api_key=#{api_key}&base=USD&currencies=XAU"
    start_time = System.monotonic_time(:millisecond)
    result = Req.get(url, receive_timeout: @timeout)
    handle_metalpriceapi_response(result, start_time)
  end

  defp handle_metalpriceapi_response({:ok, %Req.Response{status: 200, body: body}}, start_time) do
    response_time = System.monotonic_time(:millisecond) - start_time

    case validate_metalpriceapi_response(body) do
      {:ok, price_data} ->
        log_success(:metalpriceapi, response_time, price_data)
        {:ok, Map.put(price_data, :response_time_ms, response_time)}

      {:error, reason} ->
        log_failure(:metalpriceapi, reason, body)
        {:error, reason}
    end
  end

  defp handle_metalpriceapi_response({:ok, %Req.Response{status: 401}}, _start_time) do
    log_failure(:metalpriceapi, :unauthorized, nil)
    {:error, :unauthorized}
  end

  defp handle_metalpriceapi_response({:ok, %Req.Response{status: status}}, _start_time) do
    log_failure(:metalpriceapi, {:http_error, status}, nil)
    {:error, {:http_error, status}}
  end

  defp handle_metalpriceapi_response({:error, %Req.TransportError{reason: :timeout}}, _start_time) do
    log_failure(:metalpriceapi, :timeout, nil)
    {:error, :timeout}
  end

  defp handle_metalpriceapi_response({:error, reason}, _start_time) do
    log_failure(:metalpriceapi, reason, nil)
    {:error, :network_error}
  end

  @doc """
  Fetches gold price from all configured providers and returns results.
  Useful for comparing reliability and response times.
  """
  @spec fetch_all() :: %{atom() => price_result()}
  def fetch_all do
    tasks = [
      Task.async(fn -> {:nbp, fetch_nbp()} end),
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
  Priority: GoldAPI (most accurate) -> MetalpriceAPI -> NBP (free fallback)
  """
  @spec fetch_with_fallback() :: price_result()
  def fetch_with_fallback do
    providers = [
      &fetch_goldapi/0,
      &fetch_metalpriceapi/0,
      &fetch_nbp/0
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

  defp validate_nbp_response(body) when is_list(body) do
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

  defp validate_nbp_response(_), do: {:error, :invalid_response}

  defp validate_goldapi_response(%{"price" => price, "timestamp" => timestamp})
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

  defp validate_goldapi_response(_), do: {:error, :invalid_response}

  defp validate_metalpriceapi_response(%{"success" => true, "rates" => %{"XAU" => rate}, "timestamp" => timestamp})
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

  defp validate_metalpriceapi_response(_), do: {:error, :invalid_response}

  defp parse_date(date_string) do
    case Date.from_iso8601(date_string) do
      {:ok, date} -> DateTime.new!(date, ~T[00:00:00], "Etc/UTC")
      _ -> DateTime.utc_now()
    end
  end

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
