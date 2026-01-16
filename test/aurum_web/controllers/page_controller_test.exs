defmodule AurumWeb.PageControllerTest do
  use AurumWeb.ConnCase

  test "GET / renders dashboard", %{conn: conn} do
    conn = get(conn, ~p"/")
    assert html_response(conn, 200) =~ "empty-portfolio"
  end
end
