defmodule TraceMeet.Repo.Migrations.CreateExtractionPipelineStorage do
  use Ecto.Migration

  def change do
    create table(:processing_run_chunks, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :processing_run_id,
          references(:processing_runs, type: :binary_id, on_delete: :delete_all), null: false

      add :sequence, :integer, null: false
      add :content, :text, null: false
      add :token_count, :integer, null: false, default: 0
      add :cleaned_start, :integer, null: false
      add :cleaned_end, :integer, null: false
      add :source_references, :map, null: false, default: %{}
      add :status, :string, null: false, default: "pending"
      add :extraction_result, :map
      add :error_message, :text
      add :started_at, :utc_datetime_usec
      add :completed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:processing_run_chunks, [:processing_run_id, :sequence])
    create index(:processing_run_chunks, [:processing_run_id, :status])

    create constraint(:processing_run_chunks, :processing_run_chunks_status_check,
             check: "status IN ('pending', 'processing', 'completed', 'failed')"
           )

    create constraint(:processing_run_chunks, :processing_run_chunks_sequence_check,
             check: "sequence > 0"
           )

    create constraint(:processing_run_chunks, :processing_run_chunks_token_count_check,
             check: "token_count >= 0"
           )

    create constraint(:processing_run_chunks, :processing_run_chunks_offsets_check,
             check: "cleaned_start >= 0 AND cleaned_end > cleaned_start"
           )

    create table(:extraction_proposals, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :processing_run_id,
          references(:processing_runs, type: :binary_id, on_delete: :delete_all), null: false

      add :fingerprint, :string, null: false
      add :category, :string, null: false
      add :title, :string, null: false
      add :description, :text, null: false
      add :owner, :string
      add :due_date, :date
      add :confidence, :decimal
      add :status, :string, null: false, default: "pending"
      add :evidence, :map, null: false, default: %{}
      add :reviewed_at, :utc_datetime_usec
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:extraction_proposals, [:processing_run_id, :fingerprint])
    create index(:extraction_proposals, [:processing_run_id, :status])

    create constraint(:extraction_proposals, :extraction_proposals_category_check,
             check:
               "category IN ('decision', 'action_item', 'commitment', 'risk', 'unresolved_question')"
           )

    create constraint(:extraction_proposals, :extraction_proposals_status_check,
             check: "status IN ('pending', 'approved', 'rejected')"
           )

    create constraint(:extraction_proposals, :extraction_proposals_confidence_check,
             check: "confidence IS NULL OR (confidence >= 0 AND confidence <= 1)"
           )

    create table(:extraction_proposal_reviews, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :extraction_proposal_id,
          references(:extraction_proposals, type: :binary_id, on_delete: :delete_all), null: false

      add :advisor_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :action, :string, null: false
      add :previous_values, :map
      add :new_values, :map
      add :notes, :text
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:extraction_proposal_reviews, [:extraction_proposal_id, :inserted_at])
    create index(:extraction_proposal_reviews, [:advisor_id, :inserted_at])

    create constraint(:extraction_proposal_reviews, :extraction_proposal_reviews_action_check,
             check: "action IN ('approved', 'rejected', 'edited')"
           )
  end
end
