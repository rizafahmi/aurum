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

    @tag :skip
    test "dashboard displays previously created items", %{conn: conn} do
      # TODO: implement
    end

    @tag :skip
    test "cookie TTL refreshed on visit", %{conn: conn} do
      # TODO: implement
    end
  end
end
