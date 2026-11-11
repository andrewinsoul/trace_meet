defmodule TraceMeet.Repo.Migrations.CreateTranscripts do
  use Ecto.Migration

  def change do
    create table(:transcripts, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :version, :integer, null: false
      add :source_type, :string, null: false
      add :original_filename, :string
      add :content, :text, null: false
      add :cleaned_content, :text
      add :cleaned_segments, :map
      add :selected_at, :utc_datetime_usec

      add :meeting_id, references(:meetings, type: :binary_id, on_delete: :delete_all),
        null: false

      add :advisor_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:transcripts, [:meeting_id, :version])
    create index(:transcripts, [:advisor_id, :meeting_id])

    create unique_index(:transcripts, [:meeting_id],
             where: "selected_at IS NOT NULL",
             name: :transcripts_one_selected_per_meeting_index
           )
  end
end
