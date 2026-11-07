defmodule TraceMeetWeb.UserAuth do
  use TraceMeetWeb, :verified_routes

  import Plug.Conn
  import Phoenix.Controller

  alias TraceMeet.Accounts
  alias TraceMeetWeb.Endpoint

  def fetch_current_user(conn, _opts) do
    user_token = get_session(conn, :user_token)
    assign(conn, :current_user, Accounts.get_user_by_session_token(user_token))
  end

  def log_in_user(conn, user) do
    token = Accounts.generate_user_session_token(user)

    Endpoint.broadcast("users_sessions:#{user.id}", "disconnect", %{})

    conn
    |> configure_session(renew: true)
    |> put_session(:user_token, token)
    |> put_session(:live_socket_id, "users_sessions:#{user.id}")
    |> redirect(to: ~p"/dashboard")
  end

  def log_out_user(conn) do
    token = get_session(conn, :user_token)
    user = if token, do: Accounts.get_user_by_session_token(token)

    if token, do: Accounts.delete_user_session_token(token)
    if user, do: Endpoint.broadcast("users_sessions:#{user.id}", "disconnect", %{})

    conn
    |> configure_session(drop: true)
    |> redirect(to: ~p"/users/log_in")
  end

  def on_mount(:mount_current_user, _params, session, socket) do
    user = Accounts.get_user_by_session_token(session["user_token"])
    {:cont, Phoenix.Component.assign(socket, :current_user, user)}
  end

  def on_mount(:ensure_authenticated, _params, session, socket) do
    case Accounts.get_user_by_session_token(session["user_token"]) do
      nil ->
        socket =
          socket
          |> Phoenix.LiveView.put_flash(:error, "You must sign in to access this page.")
          |> Phoenix.LiveView.redirect(to: ~p"/users/log_in")

        {:halt, socket}

      user ->
        {:cont, Phoenix.Component.assign(socket, :current_user, user)}
    end
  end

  def on_mount(:redirect_if_authenticated, _params, session, socket) do
    if Accounts.get_user_by_session_token(session["user_token"]) do
      {:halt, Phoenix.LiveView.redirect(socket, to: ~p"/dashboard")}
    else
      {:cont, Phoenix.Component.assign(socket, :current_user, nil)}
    end
  end
end
