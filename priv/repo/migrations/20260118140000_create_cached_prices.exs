defmodule Aurum.Repo.Migrations.CreateCachedPrices do
  use Ecto.Migration

  def change do
    create table(:cached_prices) do
      add :price_per_oz, :decimal, null: false
      add :price_per_gram, :decimal, null: false
      add :currency, :string, null: false, default: "USD"
      add :source, :string
      add :fetched_at, :utc_datetime, null: false

      timestamps()
    end

    create index(:cached_prices, [:fetched_at])
  end
end
