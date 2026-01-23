defmodule AurumWeb.OptionalRecoveryEmailTest do
  use AurumWeb.ConnCase, async: false

  @moduletag :vault_feature

  describe "US-105: Optional Recovery Email" do
    test "prompt appears after adding first item", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test Gold Bar")
      |> fill_in("Weight (grams)", with: "31.1035")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "2500.00")
      |> click_button("Add Asset")
      |> assert_has("#recovery-email-prompt")
      |> assert_has("#recovery-email-prompt", text: "Add email to protect your vault?")
    end

    test "prompt is dismissible", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test Gold Bar")
      |> fill_in("Weight (grams)", with: "31.1035")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "2500.00")
      |> click_button("Add Asset")
      |> assert_has("#recovery-email-prompt")
      |> click_button("Not now")
      |> refute_has("#recovery-email-prompt")
    end

    test "prompt does not reappear after dismissal", %{conn: conn} do
      session =
        conn
        |> visit("/items/new")
        |> fill_in("Name", with: "First Item")
        |> fill_in("Weight (grams)", with: "10")
        |> select("Purity", option: "24K")
        |> fill_in("Purchase price", with: "500.00")
        |> click_button("Add Asset")
        |> click_button("Not now")

      session
      |> visit("/items/new")
      |> fill_in("Name", with: "Second Item")
      |> fill_in("Weight (grams)", with: "20")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "1000.00")
      |> click_button("Add Asset")
      |> refute_has("#recovery-email-prompt")
    end

    test "email saved to central database on submission", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test Gold Bar")
      |> fill_in("Weight (grams)", with: "31.1035")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "2500.00")
      |> click_button("Add Asset")
      |> assert_has("#recovery-email-prompt")
      |> fill_in("Email", with: "user@example.com")
      |> click_button("Add recovery email")

      vault = get_latest_vault()
      assert vault.recovery_email == "user@example.com"
    end

    test "email added confirmation shown after submission", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test Gold Bar")
      |> fill_in("Weight (grams)", with: "31.1035")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "2500.00")
      |> click_button("Add Asset")
      |> fill_in("Email", with: "user@example.com")
      |> click_button("Add recovery email")
      |> refute_has("#recovery-email-prompt")
      |> assert_has("[role=alert]", text: "Recovery email added")
    end

    test "validates email format before saving", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test Gold Bar")
      |> fill_in("Weight (grams)", with: "31.1035")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "2500.00")
      |> click_button("Add Asset")
      |> fill_in("Email", with: "invalid-email")
      |> click_button("Add recovery email")
      |> assert_has("#recovery-email-prompt")
      |> assert_has("p", text: "has invalid format")
    end

    test "prompt does not appear for returning users with existing items", %{conn: conn} do
      {:ok, _item} =
        Aurum.Portfolio.create_item(%{
          name: "Existing Item",
          category: :bar,
          weight: Decimal.new("10"),
          weight_unit: :grams,
          purity: 24,
          quantity: 1,
          purchase_price: Decimal.new("500")
        })

      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Another Item")
      |> fill_in("Weight (grams)", with: "20")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "1000.00")
      |> click_button("Add Asset")
      |> refute_has("#recovery-email-prompt")
    end
  end

  defp get_latest_vault do
    import Ecto.Query

    Aurum.Accounts.Vault
    |> order_by(desc: :inserted_at)
    |> limit(1)
    |> Aurum.Accounts.Repo.one()
  end
end
