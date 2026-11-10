defmodule TraceMeet.Accounts do
  import Ecto.Query, warn: false

  alias TraceMeet.Repo
  alias TraceMeet.Accounts.{User, UserToken}

  @session_validity_days 60

  def change_user_registration(%User{} = user, attrs \\ %{}) do
    User.registration_changeset(user, attrs)
  end

  def register_user(attrs) do
    changeset = User.registration_changeset(%User{}, attrs)

    if changeset.valid? do
      password = Ecto.Changeset.get_field(changeset, :password)

      changeset
      |> Ecto.Changeset.put_change(:hashed_password, TraceMeet.Accounts.Password.hash(password))
      |> Repo.insert()
      |> case do
        {:ok, user} ->
          {:ok, %{user | password: nil, password_confirmation: nil}}

        error ->
          error
      end
    else
      {:error, changeset}
    end
  end

  def update_user_time_zone(%User{time_zone: time_zone} = user, time_zone)
      when is_binary(time_zone),
      do: {:ok, user}

  def update_user_time_zone(%User{} = user, time_zone) when is_binary(time_zone) do
    if valid_time_zone?(time_zone) do
      user
      |> Ecto.Changeset.change(time_zone: time_zone)
      |> Repo.update()
    else
      {:error, :invalid_time_zone}
    end
  end

  def valid_time_zone?(time_zone) do
    time_zone == "Etc/UTC" or
      time_zone in Tzdata.zone_list()
  end

  def authenticate_user(email, password)
      when is_binary(email) and is_binary(password) do
    user = Repo.get_by(User, email: String.downcase(String.trim(email)))

    if user && TraceMeet.Accounts.Password.verify(password, user.hashed_password) do
      {:ok, user}
    else
      TraceMeet.Accounts.Password.dummy_verify(password)
      {:error, :invalid_credentials}
    end
  end

  def authenticate_user(_, password) do
    TraceMeet.Accounts.Password.dummy_verify(password)
    {:error, :invalid_credentials}
  end

  def generate_user_session_token(%User{} = user) do
    {:ok, token} =
      Repo.transaction(fn ->
        Repo.one!(
          from(u in User, where: u.id == ^user.id, lock: "FOR UPDATE")
        )

        from(t in UserToken,
          where: t.user_id == ^user.id and t.context == "session"
        )
        |> Repo.delete_all()

        token = :crypto.strong_rand_bytes(32)

        %UserToken{user_id: user.id}
        |> UserToken.changeset(%{
          token: :crypto.hash(:sha256, token),
          context: "session"
        })
        |> Repo.insert!()

        token
      end)

    token
  end

  def get_user_by_session_token(token) when is_binary(token) do
    hashed_token = :crypto.hash(:sha256, token)
    cutoff = DateTime.add(DateTime.utc_now(), -@session_validity_days * 24 * 60 * 60, :second)

    from(t in UserToken,
      join: u in assoc(t, :user),
      where: t.token == ^hashed_token and t.context == "session" and t.inserted_at > ^cutoff,
      select: u
    )
    |> Repo.one()
  end

  def get_user_by_session_token(_), do: nil

  def delete_user_session_token(token) when is_binary(token) do
    hashed_token = :crypto.hash(:sha256, token)

    from(t in UserToken, where: t.token == ^hashed_token and t.context == "session")
    |> Repo.delete_all()

    :ok
  end

  def delete_user_session_token(_), do: :ok
end
