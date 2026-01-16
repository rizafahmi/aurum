defmodule AurumWeb.ValidateItemFormTest do
  use AurumWeb.ConnCase, async: true

  @moduletag :skip

  describe "US-012: Validate Item Form Inputs" do
    test "empty name shows required error", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "")
      |> select("Category", option: "Bar")
      |> fill_in("Weight", with: "10")
      |> select("Purity", option: "24K")
      |> fill_in("Quantity", with: "1")
      |> fill_in("Purchase price", with: "500")
      |> click_button("Save")
      |> assert_has("p", text: "can't be blank")
    end

    test "negative weight shows appropriate error", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test")
      |> select("Category", option: "Bar")
      |> fill_in("Weight", with: "-5")
      |> select("Purity", option: "24K")
      |> fill_in("Quantity", with: "1")
      |> fill_in("Purchase price", with: "500")
      |> click_button("Save")
      |> assert_has("p", text: "must be greater than 0")
    end

    test "zero weight shows appropriate error", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test")
      |> select("Category", option: "Bar")
      |> fill_in("Weight", with: "0")
      |> select("Purity", option: "24K")
      |> fill_in("Quantity", with: "1")
      |> fill_in("Purchase price", with: "500")
      |> click_button("Save")
      |> assert_has("p", text: "must be greater than 0")
    end

    test "purity over 100% shows error", %{conn: conn} do
      # This would require custom purity input
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test")
      |> select("Category", option: "Bar")
      |> fill_in("Weight", with: "10")
      |> fill_in("Custom purity", with: "105")
      |> fill_in("Quantity", with: "1")
      |> fill_in("Purchase price", with: "500")
      |> click_button("Save")
      |> assert_has("p", text: "must be less than or equal to 100")
    end

    test "negative purity shows error", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test")
      |> select("Category", option: "Bar")
      |> fill_in("Weight", with: "10")
      |> fill_in("Custom purity", with: "-5")
      |> fill_in("Quantity", with: "1")
      |> fill_in("Purchase price", with: "500")
      |> click_button("Save")
      |> assert_has("p", text: "must be greater than 0")
    end

    test "errors display inline next to relevant field", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "")
      |> fill_in("Weight", with: "-1")
      |> fill_in("Quantity", with: "0")
      |> click_button("Save")
      |> assert_has("#item-name + p", text: "can't be blank")
      |> assert_has("#item-weight + p", text: "must be greater than 0")
    end

    test "form does not submit until validations pass", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "")
      |> click_button("Save")
      |> assert_path("/items/new")
    end
  end
end
