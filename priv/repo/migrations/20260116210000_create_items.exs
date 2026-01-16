defmodule Aurum.Repo.Migrations.CreateItems do
  use Ecto.Migration

  def change do
    create table(:items) do
      add :name, :string, null: false
      add :category, :string, null: false
      add :weight, :decimal, null: false
      add :weight_unit, :string, null: false
      add :purity, :integer, null: false
      add :quantity, :integer, null: false
      add :purchase_price, :decimal, null: false
      add :purchase_date, :date
      add :notes, :text

      timestamps()
    end
  end
end
