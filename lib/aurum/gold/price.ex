defmodule Aurum.Gold.Price do
  @moduledoc """
  Schema for gold price history.
  """
  use Ecto.Schema
  import Ecto.Changeset

  schema "prices" do
    field :currency, :string
    field :spot_price_usd, :decimal
    field :spot_price_idr, :decimal
    field :exchange_rate, :decimal
    field :fetched_at, :utc_datetime

    timestamps()
  end

  def categories do
    [:USD, :IDR]
  end

  def changeset(price, attrs) do
    price
    |> cast(attrs, [:currency, :spot_price_usd, :spot_price_idr, :exchange_rate, :fetched_at])
    |> validate_required([:currency, :spot_price_usd, :spot_price_idr, :exchange_rate, :fetched_at])
    |> validate_number(:spot_price_usd, greater_than: 0)
    |> validate_number(:spot_price_idr, greater_than: 0)
    |> validate_number(:exchange_rate, greater_than: 0)
  end
end
