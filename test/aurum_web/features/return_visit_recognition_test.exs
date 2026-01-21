defmodule AurumWeb.ReturnVisitRecognitionTest do
  use AurumWeb.ConnCase, async: false

  @moduletag :vault_feature

  describe "US-102: Return Visit Recognition" do
    test "valid cookie loads correct vault data", %{conn: conn} do
      # First visit: creates vault and gets cookie
      conn1 = get(conn, "/")
      vault_id_1 = conn1.private[:vault_credentials].vault_id

      # Extract the cookie for reuse
      vault_cookie = conn1.resp_cookies["_aurum_vault"]

      # Second visit: use same cookie
      conn2 =
        build_conn()
        |> put_req_cookie("_aurum_vault", vault_cookie.value)
        |> get("/")

      vault_id_2 = conn2.private[:vault_credentials].vault_id

      assert vault_id_1 == vault_id_2,
             "Expected same vault to be loaded on return visit"

      assert conn2.status == 200
    end

    test "no login prompt shown", %{conn: conn} do
      # First visit: creates vault
      conn1 = get(conn, "/")
      vault_cookie = conn1.resp_cookies["_aurum_vault"]

      # Second visit: should go straight to dashboard, no login
      conn2 =
        build_conn()
        |> put_req_cookie("_aurum_vault", vault_cookie.value)
        |> get("/")

      # Verify dashboard is shown
      assert html_response(conn2, 200) =~ "dashboard-content"

      # Verify no login elements present
      refute html_response(conn2, 200) =~ "login"
      refute html_response(conn2, 200) =~ "password"
      refute html_response(conn2, 200) =~ "sign in"
    end

    test "dashboard displays previously created items", %{conn: conn} do
      # Create an item first
      {:ok, item} =
        Aurum.Portfolio.create_item(%{
          name: "Test Gold Bar",
          weight: "100.0",
          weight_unit: "grams",
          purity: 24,
          category: "bar",
          quantity: 1,
          purchase_price: "5000.00"
        })

      # Visit items page (uses PhoenixTest which handles LiveView mount)
      conn
      |> visit("/items")
      |> assert_has("#items-list", text: "Test Gold Bar")

      # Cleanup
      Aurum.Portfolio.delete_item(item)
    end

    @tag :skip
    test "cookie TTL refreshed on visit", %{conn: conn} do
      # TODO: implement
    end
  end
end
