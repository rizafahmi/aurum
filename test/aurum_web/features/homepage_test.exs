defmodule AurumWeb.HomepageTest do
  use AurumWeb.ConnCase, async: true

  test "GET / has branding", %{conn: conn} do
    conn
    |> visit("/")
    |> assert_has("h1", text: "VAULT STATUS")
  end
end
