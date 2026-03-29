defmodule AurumWeb.PortfolioDashboardLiveTest do
  use AurumWeb.ConnCase, async: true

  import Phoenix.LiveViewTest
  import Aurum.Gold
  import Aurum.Portfolio

  describe "mount/3" do
    test "assigns initial state and subscribes to price updates" do
      {:ok, _view, _html} = live(~p"/portfolio")

      assert has_element?("#holdings")
      assert has_element?("#portfolio-metrics")
      assert has_element?("#add-holding-form")
    end

    test "displays empty portfolio message when no holdings exist" do
      {:ok, _view, _html} = live(~p"/portfolio")

      assert has_element?("p", text: "No holdings yet")
    end

    test "displays holdings list when holdings exist" do
      _holding = insert_holding!(name: "Test Gold Coin", category: "coin")

      {:ok, _view, _html} = live(~p"/portfolio")

      assert has_element?("[data-holding-id]")
      assert has_element?("h3", text: "Test Gold Coin")
      refute has_element?("p", text: "No holdings yet")
    end
  end

  describe "handle_event/3 - save" do
    test "adds holding successfully with valid data" do
      {:ok, _view, _html} = live(~p"/portfolio")

      params = %{
        "holding" => %{
          "name" => "New Gold Bar",
          "category" => "bar",
          "weight" => "10.0",
          "weight_unit" => "troy_ounces",
          "purity" => "0.9167",
          "quantity" => "1",
          "cost_basis" => "20000.00"
        }
      }

      _view
      |> form("#add-holding-form", params)
      |> render_submit()
      |> follow_redirect(~p"/portfolio")

      {:ok, _view, _html} = live(~p"/portfolio")
      assert has_element?("h3", text: "New Gold Bar")
      assert has_element?(".flash-info", text: "Holding added successfully!")
    end

    test "displays errors with invalid data" do
      {:ok, _view, _html} = live(~p"/portfolio")

      params = %{
        "holding" => %{
          "name" => "",
          "category" => "coin",
          "weight" => "invalid",
          "weight_unit" => "troy_ounces",
          "purity" => "1.0",
          "quantity" => "1",
          "cost_basis" => "2000.00"
        }
      }

      _view
      |> form("#add-holding-form", params)
      |> render_change()

      assert has_element?(".text-error")
    end
  end

  describe "handle_event/3 - delete" do
    test "deletes holding successfully" do
      holding = insert_holding!(name: "Test Coin", category: "coin")

      {:ok, _view, _html} = live(~p"/portfolio")
      assert has_element?("[data-holding-id]")

      _view
      |> element("[data-holding-id] button[phx-click=\"delete\"]")
      |> render_click()

      {:ok, _view, _html} = live(~p"/portfolio")
      assert has_element?(".flash-info", text: "Holding deleted successfully!")
      refute has_element?("[data-holding-id]")
    end
  end

  describe "handle_event/3 - validate" do
    test "updates form state on validation" do
      {:ok, _view, _html} = live(~p"/portfolio")

      params = %{
        "holding" => %{
          "name" => "Test Name",
          "category" => "coin",
          "weight" => "1.0",
          "weight_unit" => "troy_ounces",
          "purity" => "0.75",
          "quantity" => "1",
          "cost_basis" => "2000.00"
        }
      }

      _view
      |> form("#add-holding-form", params)
      |> render_change()

      assert has_element?("#add-holding-form")
    end
  end

  describe "handle_info/2 - price updates" do
    test "receives and displays price updates from PubSub" do
      {:ok, _view, _html} = live(~p"/portfolio")

      Phoenix.PubSub.broadcast(
        Aurum.PubSub,
        "price_updates",
        {:gold_price, %{idr: Decimal.new("36000000"), usd: Decimal.new("2400.00")}}
      )

      Process.sleep(100)

      {:ok, _view, _html} = live(~p"/portfolio")
      assert has_element?("#current-price")
      assert has_element?("#portfolio-metrics")
    end

    test "recalculates portfolio metrics when price updates" do
      _holding = insert_holding!(name: "Test Coin", category: "coin", weight: "1.0", cost_basis: "2000.00")

      {:ok, _view, _html} = live(~p"/portfolio")

      initial_html = render(_view)
      initial_metrics = element(_view, "#portfolio-metrics") |> render() |> Floki.parse()

      Phoenix.PubSub.broadcast(
        Aurum.PubSub,
        "price_updates",
        {:gold_price, %{idr: Decimal.new("36000000"), usd: Decimal.new("2400.00")}}
      )

      Process.sleep(100)

      {:ok, _view, _html} = live(~p"/portfolio")
      updated_metrics = element(_view, "#portfolio-metrics") |> render() |> Floki.parse()

      refute initial_metrics == updated_metrics
    end
  end

  describe "real-time streaming" do
    test "streams holdings with phx-update=\"stream\"" do
      insert_holding!(name: "Coin 1", category: "coin")
      insert_holding!(name: "Coin 2", category: "bar")

      {:ok, _view, _html} = live(~p"/portfolio")

      holdings_container = element(_view, "#holdings")
      assert render(holdings_container) =~ "phx-update=\"stream\""
    end

    test "adds new holdings to stream dynamically" do
      {:ok, _view, _html} = live(~p"/portfolio")

      initial_count = _view
      |> element("#holdings")
      |> render()
      |> Floki.parse()
      |> Floki.find("div[data-holding-id]")
      |> length()

      params = %{
        "holding" => %{
          "name" => "New Coin",
          "category" => "coin",
          "weight" => "1.0",
          "weight_unit" => "troy_ounces",
          "purity" => "0.75",
          "quantity" => "1",
          "cost_basis" => "2000.00"
        }
      }

      _view
      |> form("#add-holding-form", params)
      |> render_submit()
      |> follow_redirect(~p"/portfolio")

      {:ok, _view, _html} = live(~p"/portfolio")
      new_count = _view
      |> element("#holdings")
      |> render()
      |> Floki.parse()
      |> Floki.find("div[data-holding-id]")
      |> length()

      assert new_count == initial_count + 1
    end
  end

  describe "portfolio metrics calculations" do
    test "displays total value correctly" do
      insert_holding!(name: "Gold Coin", category: "coin", weight: "1.0", purity: "0.75", cost_basis: "2000.00")

      {:ok, _view, _html} = live(~p"/portfolio")

      assert has_element?("#total-value")
      assert has_element?("#total-cost-basis")
      assert has_element?("#roi")
    end

    test "displays weight breakdown by category" do
      insert_holding!(name: "Coin", category: "coin", weight: "1.0", cost_basis: "2000.00")
      insert_holding!(name: "Bar", category: "bar", weight: "10.0", cost_basis: "20000.00")

      {:ok, _view, _html} = live(~p"/portfolio")

      assert has_element?("#weight-breakdown")
      assert has_element?("[data-category=\"coin\"]")
      assert has_element?("[data-category=\"bar\"]")
    end
  end

  describe "weight unit conversion" do
    test "correctly calculates portfolio value for gram holdings" do
      insert_holding!(name: "Gram Coin", category: "coin", weight: "31.1034768", weight_unit: "grams", purity: "1.0", cost_basis: "2350.50")

      {:ok, _view, _html} = live(~p"/portfolio")

      assert has_element?("#total-value")
    end

    test "correctly calculates portfolio value for mixed units" do
      insert_holding!(name: "Gram Coin", category: "coin", weight: "31.1034768", weight_unit: "grams", purity: "1.0", cost_basis: "2350.50")
      insert_holding!(name: "Troy Bar", category: "bar", weight: "1.0", weight_unit: "troy_ounces", purity: "0.9167", cost_basis: "2000.00")

      {:ok, _view, _html} = live(~p"/portfolio")

      assert has_element?("#total-value")
      assert has_element?("#total-cost-basis")
    end
  end

  defp insert_holding!(attrs) do
    default_attrs = %{
      name: "Test Gold",
      category: "coin",
      weight: "1.0",
      weight_unit: "troy_ounces",
      purity: "0.75",
      quantity: 1,
      cost_basis: "2000.00"
    }

    merged_attrs = Map.merge(default_attrs, attrs)

    {:ok, holding} = Gold.create_holding(merged_attrs)
    holding
  end
end
