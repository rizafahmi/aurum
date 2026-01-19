defmodule Aurum.Gold.CachedPrice do
  @moduledoc """
  Schema for persisting gold price cache to survive app restarts.
  """

  use Ecto.Schema
  import Ecto.Query

  alias Aurum.Repo

  schema "cached_prices" do
    field :price_per_oz, :decimal
    field :price_per_gram, :decimal
    field :currency, :string, default: "IDR"
    field :source, :string
    field :fetched_at, :utc_datetime

    timestamps()
  end

  @doc """
  Returns the most recently cached price, or nil if none exists.
  """
  @spec get_latest() :: %__MODULE__{} | nil
  def get_latest do
    __MODULE__
    |> order_by(desc: :fetched_at)
    |> limit(1)
    |> Repo.one()
  end

  @doc """
  Saves a new cached price record.
  """
  @spec save(map(), DateTime.t()) :: {:ok, %__MODULE__{}} | {:error, Ecto.Changeset.t()}
  def save(price_data, fetched_at) do
    %__MODULE__{
      price_per_oz: to_decimal(price_data[:price_per_oz] || price_data["price_per_oz"]),
      price_per_gram: to_decimal(price_data[:price_per_gram] || price_data["price_per_gram"]),
      currency: price_data[:currency] || price_data["currency"] || "IDR",
      source: to_string(price_data[:source] || price_data["source"] || "unknown"),
      fetched_at: DateTime.truncate(fetched_at, :second)
    }
    |> Repo.insert()
  end

  @doc """
  Converts a cached price record back to the map format used by PriceCache.
  """
  @spec to_price_data(%__MODULE__{}) :: map()
  def to_price_data(%__MODULE__{} = cached) do
    %{
      price_per_oz: cached.price_per_oz,
      price_per_gram: cached.price_per_gram,
      currency: cached.currency,
      timestamp: cached.fetched_at,
      source: source_to_atom(cached.source)
    }
  end

  @known_sources ["nbp", "kitco", "lbma", "test", "mock"]

  defp source_to_atom(source) when source in @known_sources do
    String.to_existing_atom(source)
  end

  defp source_to_atom(_source), do: :unknown

  defp to_decimal(nil), do: nil
  defp to_decimal(%Decimal{} = d), do: d
  defp to_decimal(value) when is_float(value), do: Decimal.from_float(value)
  defp to_decimal(value) when is_integer(value), do: Decimal.new(value)
  defp to_decimal(value) when is_binary(value), do: Decimal.new(value)
end
