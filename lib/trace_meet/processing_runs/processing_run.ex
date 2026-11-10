defmodule TraceMeet.ProcessingRuns.ProcessingRun do
  use Ecto.Schema
  import Ecto.Changeset

  alias TraceMeet.Accounts.User
  alias TraceMeet.Transcripts.Transcript

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  @statuses ["queued", "processing", "completed", "failed", "cancelled"]

  schema "processing_runs" do
    field :status, :string, default: "queued"
    field :oban_job_id, :integer
    field :attempt_count, :integer, default: 0
    field :started_at, :utc_datetime_usec
    field :completed_at, :utc_datetime_usec
    field :failed_at, :utc_datetime_usec
    field :error_message, :string
    field :prompt_version, :string
    field :prompt_snapshot, :string
    field :prompt_sha256, :string
    field :model, :string
    field :guardrails_snapshot, :map, default: %{}
    field :advisor_prompt_version, :integer
    field :advisor_prompt_snapshot, :string, default: ""
    field :advisor_prompt_sha256, :string
    belongs_to :advisor_prompt, TraceMeet.AI.AdvisorPrompt
    field :cleaned_content, :string
    field :cleaned_segments, :map

    belongs_to :transcript, Transcript
    belongs_to :advisor, User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(run, attrs) do
    run
    |> cast(attrs, [
      :transcript_id,
      :advisor_id,
      :status,
      :oban_job_id,
      :attempt_count,
      :started_at,
      :completed_at,
      :failed_at,
      :error_message,
      :prompt_version,
      :prompt_snapshot,
      :prompt_sha256,
      :model,
      :guardrails_snapshot,
      :advisor_prompt_id,
      :advisor_prompt_version,
      :advisor_prompt_snapshot,
      :advisor_prompt_sha256
    ])
    |> validate_required([
      :transcript_id,
      :advisor_id,
      :status,
      :attempt_count,
      :prompt_version,
      :prompt_snapshot,
      :prompt_sha256,
      :model,
      :guardrails_snapshot,
      :advisor_prompt_id,
      :advisor_prompt_version,
      :advisor_prompt_snapshot,
      :advisor_prompt_sha256
    ])
    |> validate_inclusion(:status, @statuses)
    |> validate_number(:attempt_count, greater_than_or_equal_to: 0)
    |> foreign_key_constraint(:transcript_id)
    |> foreign_key_constraint(:advisor_id)
    |> foreign_key_constraint(:advisor_prompt_id)
    |> unique_constraint(:transcript_id, name: :processing_runs_one_active_per_transcript_index)
    |> check_constraint(:status, name: :processing_runs_status_check)
    |> check_constraint(:attempt_count, name: :processing_runs_attempt_count_check)
  end

  def transition_changeset(run, attrs \\ %{}) do
    cast(run, attrs, [
      :status,
      :attempt_count,
      :started_at,
      :completed_at,
      :failed_at,
      :error_message,
      :cleaned_content,
      :cleaned_segments
    ])
    |> validate_inclusion(:status, @statuses)
    |> check_constraint(:status, name: :processing_runs_status_check)
  end
end
