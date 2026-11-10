defmodule TraceMeet.ProcessingRuns.ProcessingRunChunk do
  use Ecto.Schema
  import Ecto.Changeset

  alias TraceMeet.ProcessingRuns.ProcessingRun

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @statuses ["pending", "processing", "completed", "failed"]

  schema "processing_run_chunks" do
    field :sequence, :integer
    field :content, :string
    field :token_count, :integer, default: 0
    field :cleaned_start, :integer
    field :cleaned_end, :integer
    field :source_references, :map, default: %{}
    field :status, :string, default: "pending"
    field :extraction_result, :map
    field :error_message, :string
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    belongs_to :processing_run, ProcessingRun
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(chunk, attrs) do
    chunk
    |> cast(attrs, [
      :sequence, :content, :token_count, :cleaned_start, :cleaned_end,
      :source_references, :status, :extraction_result, :error_message,
      :started_at, :completed_at
    ])
    |> validate_required([:processing_run_id, :sequence, :content, :cleaned_start, :cleaned_end])
    |> validate_number(:sequence, greater_than: 0)
    |> validate_number(:token_count, greater_than_or_equal_to: 0)
    |> validate_number(:cleaned_start, greater_than_or_equal_to: 0)
    |> validate_number(:cleaned_end, greater_than: 0)
    |> validate_offset_order()
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:content, min: 1)
    |> check_constraint(:status, name: :processing_run_chunks_status_check)
    |> check_constraint(:sequence, name: :processing_run_chunks_sequence_check)
    |> check_constraint(:token_count, name: :processing_run_chunks_token_count_check)
    |> check_constraint(:cleaned_end, name: :processing_run_chunks_offsets_check)
    |> unique_constraint([:processing_run_id, :sequence])
    |> foreign_key_constraint(:processing_run_id)
  end
  defp validate_offset_order(changeset) do
    start_offset = get_field(changeset, :cleaned_start)
    end_offset = get_field(changeset, :cleaned_end)

    if is_integer(start_offset) and is_integer(end_offset) and end_offset <= start_offset do
      add_error(changeset, :cleaned_end, "must be greater than cleaned_start")
    else
      changeset
    end
  end
end
