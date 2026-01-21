defmodule Aurum.Accounts.Repo.Migrations.CreateVaults do
  use Ecto.Migration

  def change do
    create table(:vaults, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :token_hash, :string, null: false
      add :recovery_email, :string
      add :email_verified_at, :utc_datetime
      add :last_accessed_at, :utc_datetime
      add :deleted_at, :utc_datetime

      timestamps(type: :utc_datetime)
    end

    create index(:vaults, [:token_hash])
    create index(:vaults, [:recovery_email])
  end
end
