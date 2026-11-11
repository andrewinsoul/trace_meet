defmodule TraceMeet.Repo.Migrations.CreateProcessingRuns do
  use Ecto.Migration

  def change do
    create table(:processing_runs, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :status, :string, null: false, default: "queued"
      add :oban_job_id, :bigint
      add :attempt_count, :integer, null: false, default: 0
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      add :failed_at, :utc_datetime_usec
      add :error_message, :text

      add :transcript_id, references(:transcripts, type: :binary_id, on_delete: :delete_all),
        null: false

      add :advisor_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime_usec)
    end

    create constraint(:processing_runs, :processing_runs_status_check,
             check: "status IN ('queued', 'processing', 'completed', 'failed', 'cancelled')"
           )

    create constraint(:processing_runs, :processing_runs_attempt_count_check,
             check: "attempt_count >= 0"
           )

    create index(:processing_runs, [:transcript_id, :inserted_at])
    create index(:processing_runs, [:advisor_id, :inserted_at])

    create unique_index(:processing_runs, [:transcript_id],
             where: "status IN ('queued', 'processing')",
             name: :processing_runs_one_active_per_transcript_index
           )
  end
end
