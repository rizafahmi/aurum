defmodule AurumWeb.ValidateItemFormTest do
  use AurumWeb.ConnCase, async: true

  describe "US-012: Validate Item Form Inputs" do
    test "empty name shows required error", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "")
      |> fill_in("Weight (grams)", with: "10")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "500")
      |> click_button("Add Asset")
      |> assert_has("p", text: "can't be blank")
    end

    test "negative weight shows appropriate error", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test")
      |> fill_in("Weight (grams)", with: "-5")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "500")
      |> click_button("Add Asset")
      |> assert_has("p", text: "must be greater than 0")
    end

    test "zero weight shows appropriate error", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "Test")
      |> fill_in("Weight (grams)", with: "0")
      |> select("Purity", option: "24K")
      |> fill_in("Purchase price", with: "500")
      |> click_button("Add Asset")
      |> assert_has("p", text: "must be greater than 0")
    end

    test "errors display inline next to relevant field", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "")
      |> fill_in("Weight (grams)", with: "-1")
      |> click_button("Add Asset")
      |> assert_has("p", text: "can't be blank")
      |> assert_has("p", text: "must be greater than 0")
    end

    test "form does not submit until validations pass", %{conn: conn} do
      conn
      |> visit("/items/new")
      |> fill_in("Name", with: "")
      |> click_button("Add Asset")
      |> assert_path("/items/new")
    end
  end
end
