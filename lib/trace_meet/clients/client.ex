defmodule TraceMeet.Clients.Client do
  use Ecto.Schema
  import Ecto.Changeset

  alias TraceMeet.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "clients" do
    field :name, :string
    field :email, :string
    field :phone, :string
    field :company, :string
    field :notes, :string
    field :archived_at, :utc_datetime_usec

    belongs_to :user, User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(client, attrs) do
    client
    |> cast(attrs, [:name, :email, :phone, :company, :notes])
    |> update_change(:name, &String.trim/1)
    |> update_change(:email, &String.downcase(String.trim(&1)))
    |> validate_required([:name])
    |> validate_length(:name, max: 160)
    |> validate_length(:email, max: 160)
    |> validate_format(:email, ~r/^[^\s]+@[^\s]+\.[^\s]+$/,
      message: "must be a valid email address"
    )
    |> validate_length(:phone, max: 40)
    |> validate_length(:company, max: 160)
    |> validate_length(:notes, max: 5_000)
  end
end
