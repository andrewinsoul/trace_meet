defmodule TraceMeet.Repo.Migrations.CreateClients do
  use Ecto.Migration

  def change do
    create table(:clients, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :email, :string
      add :phone, :string
      add :company, :string
      add :notes, :text
      add :archived_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:clients, [:user_id, :inserted_at])
    create index(:clients, [:user_id, :archived_at])
  end
end
