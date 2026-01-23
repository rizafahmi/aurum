defmodule Aurum.Accounts do
  @moduledoc """
  Context for vault management.
  """

  alias Aurum.Accounts.{Repo, Vault}

  @token_pepper Application.compile_env(:aurum, :token_pepper, "aurum_vault_pepper")

  @doc """
  Creates a new vault with a secure token.
  Returns `{:ok, vault, raw_token}` where `raw_token` is the unhashed token for the cookie.
  """
  def create_vault do
    raw_token = generate_token()
    token_hash = hash_token(raw_token)

    attrs = %{
      token_hash: token_hash,
      last_accessed_at: DateTime.utc_now()
    }

    case %Vault{} |> Vault.changeset(attrs) |> Repo.insert() do
      {:ok, vault} -> {:ok, vault, raw_token}
      {:error, changeset} -> {:error, changeset}
    end
  end

  @doc """
  Verifies a vault token and returns the vault if valid.
  """
  def verify_vault(vault_id, raw_token) do
    case Repo.get(Vault, vault_id) do
      nil ->
        {:error, :not_found}

      %Vault{deleted_at: deleted_at} when not is_nil(deleted_at) ->
        {:error, :deleted}

      %Vault{token_hash: stored_hash} = vault ->
        if Plug.Crypto.secure_compare(stored_hash, hash_token(raw_token)) do
          {:ok, vault}
        else
          {:error, :invalid_token}
        end
    end
  end

  @doc """
  Updates the last_accessed_at timestamp for a vault.
  """
  def touch_vault(%Vault{} = vault) do
    vault
    |> Vault.changeset(%{last_accessed_at: DateTime.utc_now()})
    |> Repo.update()
  end

  @doc """
  Gets a vault by ID.
  """
  def get_vault(vault_id), do: Repo.get(Vault, vault_id)

  @doc """
  Marks the recovery email prompt as dismissed for a vault.
  """
  def dismiss_recovery_email_prompt(vault_id) do
    case get_vault(vault_id) do
      nil ->
        {:error, :not_found}

      vault ->
        vault
        |> Vault.changeset(%{recovery_email_prompt_dismissed: true})
        |> Repo.update()
    end
  end

  @doc """
  Sets the recovery email for a vault.
  """
  def set_recovery_email(vault_id, email) do
    case get_vault(vault_id) do
      nil ->
        {:error, :not_found}

      vault ->
        vault
        |> Vault.changeset(%{recovery_email: email})
        |> Repo.update()
    end
  end

  defp generate_token do
    :crypto.strong_rand_bytes(32) |> Base.url_encode64(padding: false)
  end

  defp hash_token(raw_token) do
    :crypto.mac(:hmac, :sha256, @token_pepper, raw_token)
    |> Base.encode64()
  end
end
