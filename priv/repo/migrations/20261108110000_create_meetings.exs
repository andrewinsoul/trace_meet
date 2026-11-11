defmodule TraceMeet.Repo.Migrations.CreateMeetings do
  use Ecto.Migration

  def change do
    create table(:meetings, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :client_id, references(:clients, type: :binary_id, on_delete: :restrict), null: false
      add :title, :string, null: false
      add :description, :text
      add :scheduled_at, :naive_datetime_usec
      add :started_at, :naive_datetime_usec
      add :ended_at, :naive_datetime_usec
      add :status, :string, null: false, default: "scheduled"
      add :archived_at, :utc_datetime_usec

      timestamps(type: :utc_datetime_usec)
    end

    create index(:meetings, [:user_id, :inserted_at])
    create index(:meetings, [:client_id, :scheduled_at])
    create index(:meetings, [:user_id, :status])
    create index(:meetings, [:user_id, :archived_at])

    create constraint(:meetings, :meetings_status_check,
             check: "status IN ('scheduled', 'in_progress', 'completed', 'cancelled')"
           )
  end
end
