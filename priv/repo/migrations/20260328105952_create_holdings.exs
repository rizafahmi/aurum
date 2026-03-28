defmodule Aurum.Repo.Migrations.CreateHoldings do
  use Ecto.Migration

  def change do
    create table(:holdings) do
      add :name, :string, null: false
      add :category, :string, null: false
      add :weight, :decimal, null: false
      add :weight_unit, :string, null: false
      add :purity, :decimal, null: false
      add :quantity, :integer, null: false, default: 1
      add :cost_basis, :decimal, null: false
      add :purchase_date, :date
      add :notes, :string

      timestamps()
    end

    create index(:holdings, [:category])
    create index(:holdings, [:purchase_date])
  end

  def down do
    drop table(:holdings)
  end
end
