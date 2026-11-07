defmodule TraceMeetWeb.PageController do
  use TraceMeetWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
