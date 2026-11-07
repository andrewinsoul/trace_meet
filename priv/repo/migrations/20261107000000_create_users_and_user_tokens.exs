defmodule TraceMeet.Repo.Migrations.CreateUsersAndUserTokens do
  use Ecto.Migration

  def change do
    create table(:users, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :email, :string, null: false
      add :hashed_password, :string, null: false

      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:users, [:email])

    create table(:user_tokens, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :token, :binary, null: false
      add :context, :string, null: false

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create unique_index(:user_tokens, [:token])
    create index(:user_tokens, [:user_id])
    create index(:user_tokens, [:context, :inserted_at])
  end
end
