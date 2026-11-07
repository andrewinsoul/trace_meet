defmodule TraceMeetWeb.PageController do
  use TraceMeetWeb, :controller

  def home(%{assigns: %{current_user: nil}} = conn, _params) do
    redirect(conn, to: ~p"/users/log_in")
  end

  def home(conn, _params) do
    redirect(conn, to: ~p"/dashboard")
  end
end
