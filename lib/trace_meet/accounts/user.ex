defmodule TraceMeet.Accounts.User do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @derive {Inspect, except: [:hashed_password, :password, :password_confirmation]}

  schema "users" do
    field :email, :string
    field :time_zone, :string, default: "Etc/UTC"
    field :hashed_password, :string, redact: true
    field :password, :string, virtual: true, redact: true
    field :password_confirmation, :string, virtual: true, redact: true

    timestamps(type: :utc_datetime_usec)
  end

  def registration_changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password, :password_confirmation])
    |> update_change(:email, &String.downcase(String.trim(&1)))
    |> validate_required([:email, :password, :password_confirmation])
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/, message: "must be a valid email address")
    |> validate_length(:email, max: 160)
    |> validate_length(:password, min: 8, max: 128)
    |> validate_confirmation(:password, message: "does not match password confirmation")
    |> unique_constraint(:email)
  end

end
