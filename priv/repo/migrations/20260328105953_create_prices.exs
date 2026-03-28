defmodule Aurum.Repo.Migrations.CreatePrices do
  use Ecto.Migration

  def change do
    create table(:prices) do
      add :currency, :string, null: false
      add :spot_price_usd, :decimal, null: false
      add :spot_price_idr, :decimal, null: false
      add :exchange_rate, :decimal, null: false
      add :fetched_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:prices, [:currency])
    create index(:prices, [:fetched_at])
  end

  def down do
    drop table(:prices)
  end
end
