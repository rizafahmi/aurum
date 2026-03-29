defmodule AurumWeb.PageControllerTest do
  use AurumWeb.ConnCase

  test "GET /", %{conn: conn} do
    conn = get(conn, "/")
    assert html_response(conn, 200) =~ "Peace of mind from prototype to production"
  end
end

