defmodule TraceMeet.Repo.Migrations.AddChunkExtractionPipeline do
  use Ecto.Migration

  def change do
    alter table(:processing_run_chunks) do
      add :attempt_count, :integer, null: false, default: 0
    end

    create constraint(:processing_run_chunks, :processing_run_chunks_attempt_count_check,
             check: "attempt_count >= 0"
           )

    create table(:chunk_extractions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :processing_run_chunk_id,
          references(:processing_run_chunks, type: :binary_id, on_delete: :delete_all), null: false
      add :categories, {:array, :string}, null: false, default: []
      add :description, :text, null: false
      add :owner, :string
      add :deadline, :date
      add :confidence, :decimal
      add :uncertainties, :map, null: false, default: %{}
      add :evidence_quotes, {:array, :text}, null: false, default: []
      add :source_segment_ids, {:array, :string}, null: false, default: []
      timestamps(type: :utc_datetime_usec)
    end

    create index(:chunk_extractions, [:processing_run_chunk_id])
    create index(:chunk_extractions, [:categories], using: :gin)
    create constraint(:chunk_extractions, :chunk_extractions_confidence_check,
             check: "confidence IS NULL OR (confidence >= 0 AND confidence <= 1)"
           )
    create constraint(:chunk_extractions, :chunk_extractions_categories_check,
             check: "cardinality(categories) > 0 AND categories <@ ARRAY['decision', 'action_item', 'commitment', 'risk', 'unresolved_question']::varchar[]"
           )

    alter table(:extraction_proposals) do
      add :categories, {:array, :string}, null: false, default: []
      add :uncertainties, :map, null: false, default: %{}
      add :rejection_reason, :text
    end

    execute "UPDATE extraction_proposals SET categories = ARRAY[category] WHERE cardinality(categories) = 0",
            "UPDATE extraction_proposals SET categories = '{}'"

    create table(:extraction_proposal_sources, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :extraction_proposal_id,
          references(:extraction_proposals, type: :binary_id, on_delete: :delete_all), null: false
      add :chunk_extraction_id,
          references(:chunk_extractions, type: :binary_id, on_delete: :delete_all), null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:extraction_proposal_sources, [:extraction_proposal_id, :chunk_extraction_id],
             name: :extraction_proposal_sources_unique_index
           )

    create table(:extraction_proposal_evidence, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :extraction_proposal_id,
          references(:extraction_proposals, type: :binary_id, on_delete: :delete_all), null: false
      add :segment_id, :string, null: false
      add :source_start, :integer
      add :source_end, :integer
      add :speaker, :string
      add :timestamp, :string
      add :quote, :text, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create index(:extraction_proposal_evidence, [:extraction_proposal_id])
    create index(:extraction_proposals, [:categories], using: :gin)
    create constraint(:extraction_proposals, :extraction_proposals_categories_check,
             check: "cardinality(categories) > 0 AND categories <@ ARRAY['decision', 'action_item', 'commitment', 'risk', 'unresolved_question']::varchar[]"
           )
    create constraint(:extraction_proposals, :extraction_proposals_rejection_reason_check,
             check: "status <> 'rejected' OR rejection_reason IS NOT NULL"
           )
    create unique_index(:extraction_proposal_evidence, [:extraction_proposal_id, :segment_id],
             name: :extraction_proposal_evidence_unique_index
           )
  end
end
