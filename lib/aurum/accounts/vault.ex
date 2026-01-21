defmodule Aurum.Accounts.Vault do
  @moduledoc """
  Schema for vault records in the central accounts database.

  Each vault represents an anonymous user's data container, identified by
  an encrypted cookie. The token_hash stores an HMAC of the bearer token.
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "vaults" do
    field :token_hash, :string
    field :recovery_email, :string
    field :email_verified_at, :utc_datetime
    field :last_accessed_at, :utc_datetime
    field :deleted_at, :utc_datetime

    timestamps(type: :utc_datetime)
  end

  @doc false
  def changeset(vault, attrs) do
    vault
    |> cast(attrs, [:token_hash, :recovery_email, :email_verified_at, :last_accessed_at, :deleted_at])
    |> validate_required([:token_hash])
  end
end
