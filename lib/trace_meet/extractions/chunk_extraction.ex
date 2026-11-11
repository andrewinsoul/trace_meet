defmodule TraceMeet.Extractions.ChunkExtraction do
  use Ecto.Schema
  import Ecto.Changeset

  alias TraceMeet.ProcessingRuns.ProcessingRunChunk

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @categories ["decision", "action_item", "commitment", "risk", "unresolved_question"]

  schema "chunk_extractions" do
    field :categories, {:array, :string}, default: []
    field :description, :string
    field :owner, :string
    field :deadline, :date
    field :confidence, :decimal
    field :uncertainties, :map, default: %{}
    field :evidence_quotes, {:array, :string}, default: []
    field :source_segment_ids, {:array, :string}, default: []
    belongs_to :processing_run_chunk, ProcessingRunChunk
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(extraction, attrs) do
    extraction
    |> cast(attrs, [
      :categories,
      :description,
      :owner,
      :deadline,
      :confidence,
      :uncertainties,
      :evidence_quotes,
      :source_segment_ids
    ])
    |> validate_required([
      :processing_run_chunk_id,
      :categories,
      :description,
      :evidence_quotes,
      :source_segment_ids
    ])
    |> validate_length(:categories, min: 1)
    |> validate_length(:evidence_quotes, min: 1)
    |> validate_length(:source_segment_ids, min: 1)
    |> validate_change(:categories, fn :categories, values ->
      if Enum.all?(values, &(&1 in @categories)),
        do: [],
        else: [categories: "contains an unsupported category"]
    end)
    |> validate_number(:confidence, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> check_constraint(:categories, name: :chunk_extractions_categories_check)
    |> check_constraint(:confidence, name: :chunk_extractions_confidence_check)
    |> foreign_key_constraint(:processing_run_chunk_id)
  end
end
