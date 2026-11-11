defmodule TraceMeet.Accounts.UserToken do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "user_tokens" do
    field :token, :binary
    field :context, :string
    belongs_to :user, TraceMeet.Accounts.User

    timestamps(updated_at: false, type: :utc_datetime_usec)
  end

  def changeset(token, attrs) do
    token
    |> cast(attrs, [:token, :context])
    |> validate_required([:token, :context, :user_id])
    |> unique_constraint(:token)
    |> foreign_key_constraint(:user_id)
  end
end
