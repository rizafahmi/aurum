defmodule Aurum.VaultDatabase.IdleCleanupTest do
  @moduledoc """
  Tests for idle vault cleanup functionality.

  These tests use real SQLite files (not sandbox) because they need to test
  the actual GenServer lifecycle and process termination behavior.
  """
  use ExUnit.Case, async: false

  alias Aurum.Accounts
  alias Aurum.VaultDatabase.DynamicRepo
  alias Aurum.VaultDatabase.Manager

  @moduletag :integration

  setup do
    Ecto.Adapters.SQL.Sandbox.checkout(Aurum.Accounts.Repo)

    on_exit(fn ->
      clean_vault_databases()
    end)

    :ok
  end

  defp clean_vault_databases do
    vault_dir = Manager.vault_databases_path()

    if File.dir?(vault_dir) do
      vault_dir
      |> File.ls!()
      |> Enum.filter(&String.starts_with?(&1, "vault_"))
      |> Enum.each(fn file ->
        File.rm(Path.join(vault_dir, file))
      end)
    end
  end

  describe "US-106: Idle Vault Cleanup" do
    test "repo process stops after idle timeout" do
      {:ok, vault, _token} = Accounts.create_vault()
      {:ok, pid} = DynamicRepo.start_repo(vault.id, idle_timeout: 100)

      assert Process.alive?(pid)

      Process.sleep(150)

      refute Process.alive?(pid)
    end

    test "next request restarts repo transparently" do
      {:ok, vault, _token} = Accounts.create_vault()

      {:ok, pid1} = DynamicRepo.start_repo(vault.id, idle_timeout: 100)
      assert Process.alive?(pid1)

      Process.sleep(150)
      refute Process.alive?(pid1)

      {:ok, pid2} = DynamicRepo.ensure_started(vault.id)
      assert Process.alive?(pid2)
      refute pid1 == pid2
    end

    test "no data loss on repo restart" do
      {:ok, vault, _token} = Accounts.create_vault()

      {:ok, _pid} = DynamicRepo.start_repo(vault.id, idle_timeout: 100)

      DynamicRepo.with_repo(vault.id, fn ->
        Aurum.Portfolio.create_item(%{
          name: "Test Gold Bar",
          category: :bar,
          weight: Decimal.new("31.1035"),
          weight_unit: :grams,
          purity: 24,
          quantity: 1,
          purchase_price: Decimal.new("2500.00")
        })
      end)

      Process.sleep(150)

      {:ok, _pid} = DynamicRepo.ensure_started(vault.id)

      items =
        DynamicRepo.with_repo(vault.id, fn ->
          Aurum.Portfolio.list_items()
        end)

      assert length(items) == 1
      assert hd(items).name == "Test Gold Bar"
    end
  end
end
