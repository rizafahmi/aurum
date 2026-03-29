defmodule AurumWeb.APIPortfolioControllerTest do
  use AurumWeb.ConnCase

  alias Aurum.Gold

  describe "index/2" do
    test "returns list of holdings" do
      {:ok, holding1} = Gold.create_holding(%{name: "Coin 1", category: "coin"})
      {:ok, holding2} = Gold.create_holding(%{name: "Bar 1", category: "bar"})

      conn = get(conn, "/api/portfolio")
      assert json_response(conn, 200)

      {:ok, body} = Jason.decode(conn.resp_body)
      assert is_list(body["holdings"])
      assert length(body["holdings"]) == 2
    end

    test "returns latest price" do
      conn = get(conn, "/api/portfolio")

      assert json_response(conn, 200)

      {:ok, body} = Jason.decode(conn.resp_body)
      assert Map.has_key?(body, "latest_price")
    end
  end

  describe "create/2" do
    test "creates holding with valid data" do
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

      conn = post(conn, "/api/portfolio", params)
      assert json_response(conn, 201)

      {:ok, body} = Jason.decode(conn.resp_body)
      assert Map.has_key?(body, "holding")
      assert body["holding"]["name"] == "New Coin"
    end

    test "returns errors with invalid data" do
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

      conn = post(conn, "/api/portfolio", params)
      assert json_response(conn, 422)

      {:ok, body} = Jason.decode(conn.resp_body)
      assert Map.has_key?(body, "errors")
    end
  end

  describe "show/2" do
    test "returns holding by id" do
      holding = insert_holding!(name: "Test Coin", category: "coin")

      conn = get(conn, "/api/portfolio/#{holding.id}")
      assert json_response(conn, 200)

      {:ok, body} = Jason.decode(conn.resp_body)
      assert Map.has_key?(body, "holding")
      assert body["holding"]["id"] == holding.id
    end

    test "returns 404 for non-existent holding" do
      conn = get(conn, "/api/portfolio/999999")
      assert json_response(conn, 404)

      {:ok, body} = Jason.decode(conn.resp_body)
      assert Map.has_key?(body, "error")
    end
  end

  describe "update/2" do
    test "updates holding with valid data" do
      holding = insert_holding!(name: "Original Coin", category: "coin")

      params = %{
        "holding" => %{
          "name" => "Updated Coin",
          "cost_basis" => "2500.00"
        }
      }

      conn = put(conn, "/api/portfolio/#{holding.id}", params)
      assert json_response(conn, 200)

      {:ok, body} = Jason.decode(conn.resp_body)
      assert Map.has_key?(body, "holding")
      assert body["holding"]["name"] == "Updated Coin"
      assert body["holding"]["cost_basis"] == "2500.00"
    end

    test "returns 404 for non-existent holding" do
      params = %{
        "holding" => %{
          "name" => "Updated Coin",
          "cost_basis" => "2500.00"
        }
      }

      conn = put(conn, "/api/portfolio/999999", params)
      assert json_response(conn, 404)

      {:ok, body} = Jason.decode(conn.resp_body)
      assert Map.has_key?(body, "error")
    end
  end

  describe "delete/2" do
    test "deletes holding successfully" do
      holding = insert_holding!(name: "To Delete", category: "coin")

      conn = delete(conn, "/api/portfolio/#{holding.id}")
      assert json_response(conn, 200)

      {:ok, body} = Jason.decode(conn.resp_body)
      assert body["success"] == true
    end

    test "returns 404 for non-existent holding" do
      conn = delete(conn, "/api/portfolio/999999")
      assert json_response(conn, 404)

      {:ok, body} = Jason.decode(conn.resp_body)
      assert Map.has_key?(body, "error")
    end
  end

  describe "metrics/2" do
    test "returns portfolio metrics" do
      insert_holding!(name: "Coin", category: "coin", weight: "1.0", cost_basis: "2000.00")
      insert_holding!(name: "Bar", category: "bar", weight: "10.0", cost_basis: "20000.00")

      conn = get(conn, "/api/portfolio/metrics")
      assert json_response(conn, 200)

      {:ok, body} = Jason.decode(conn.resp_body)
      assert Map.has_key?(body, "metrics")
      assert Map.has_key?(body["metrics"], "total_value_usd")
      assert Map.has_key?(body["metrics"], "roi")
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

    merged_attrs = Map.merge(default_attrs, Map.new(attrs))

    {:ok, holding} = Gold.create_holding(merged_attrs)
    holding
  end

end
