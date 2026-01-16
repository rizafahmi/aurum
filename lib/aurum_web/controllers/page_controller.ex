defmodule AurumWeb.PageController do
  use AurumWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
