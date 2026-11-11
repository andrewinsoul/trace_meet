defmodule TraceMeetWeb.UserSessionController do
  use TraceMeetWeb, :controller

  alias TraceMeet.Accounts
  alias TraceMeetWeb.UserAuth

  def create(conn, %{"user" => %{"email" => email, "password" => password}}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Welcome back!")
        |> UserAuth.log_in_user(user)

      {:error, :invalid_credentials} ->
        conn
        |> put_flash(:error, "Invalid email or password.")
        |> redirect(to: ~p"/users/log_in")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Enter your email and password.")
    |> redirect(to: ~p"/users/log_in")
  end

  def delete(conn, _params), do: UserAuth.log_out_user(conn)
end
