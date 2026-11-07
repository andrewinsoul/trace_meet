defmodule TraceMeetWeb.UserRegistrationController do
  use TraceMeetWeb, :controller

  alias TraceMeet.Accounts
  alias TraceMeetWeb.UserAuth

  def create(conn, %{"user" => attrs}) do
    case Accounts.register_user(attrs) do
      {:ok, user} ->
        conn
        |> put_flash(:info, "Your TraceMeet account is ready.")
        |> UserAuth.log_in_user(user)

      {:error, _changeset} ->
        conn
        |> put_flash(:error, "We couldn't create your account. Check your details and try again.")
        |> redirect(to: ~p"/users/register")
    end
  end

  def create(conn, _params) do
    conn
    |> put_flash(:error, "Complete the required fields to create your account.")
    |> redirect(to: ~p"/users/register")
  end
end
