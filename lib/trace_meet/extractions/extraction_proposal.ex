defmodule TraceMeet.Extractions.ExtractionProposal do
  use Ecto.Schema
  import Ecto.Changeset

  alias TraceMeet.ProcessingRuns.ProcessingRun
  alias TraceMeet.Extractions.{ExtractionProposalReview, ExtractionProposalSource, ExtractionProposalEvidence}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @categories ["decision", "action_item", "commitment", "risk", "unresolved_question"]
  @statuses ["pending", "approved", "rejected"]

  schema "extraction_proposals" do
    field :fingerprint, :string
    field :category, :string
    field :categories, {:array, :string}, default: []
    field :uncertainties, :map, default: %{}
    field :title, :string
    field :description, :string
    field :owner, :string
    field :due_date, :date
    field :confidence, :decimal
    field :status, :string, default: "pending"
    field :evidence, :map, default: %{}
    field :reviewed_at, :utc_datetime_usec
    field :rejection_reason, :string
    belongs_to :processing_run, ProcessingRun
    has_many :reviews, ExtractionProposalReview
    has_many :sources, ExtractionProposalSource
    has_many :evidence_records, ExtractionProposalEvidence
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(proposal, attrs) do
    proposal
    |> cast(attrs, [:fingerprint, :category, :categories, :uncertainties, :title, :description, :owner, :due_date, :confidence, :status, :evidence, :reviewed_at, :rejection_reason])
    |> put_categories_fallback()
    |> validate_required([:processing_run_id, :fingerprint, :category, :title, :description, :status, :evidence])
    |> validate_inclusion(:category, @categories)
    |> validate_length(:categories, min: 1)
    |> validate_change(:categories, fn :categories, values ->
      if Enum.all?(values, &(&1 in @categories)), do: [], else: [categories: "contains an unsupported category"]
    end)
    |> validate_rejection_reason()
    |> validate_inclusion(:status, @statuses)
    |> validate_length(:title, max: 255)
    |> validate_format(:fingerprint, ~r/\A[0-9a-f]{64}\z/)
    |> validate_number(:confidence, greater_than_or_equal_to: 0, less_than_or_equal_to: 1)
    |> unique_constraint([:processing_run_id, :fingerprint])
    |> foreign_key_constraint(:processing_run_id)
    |> check_constraint(:category, name: :extraction_proposals_category_check)
    |> check_constraint(:categories, name: :extraction_proposals_categories_check)
    |> check_constraint(:rejection_reason, name: :extraction_proposals_rejection_reason_check)
    |> check_constraint(:status, name: :extraction_proposals_status_check)
    |> check_constraint(:confidence, name: :extraction_proposals_confidence_check)
  end

  defp put_categories_fallback(changeset) do
    case get_field(changeset, :categories) do
      [] -> put_change(changeset, :categories, [get_field(changeset, :category)])
      _ -> changeset
    end
  end

  defp validate_rejection_reason(changeset) do
    if get_field(changeset, :status) == "rejected" do
      validate_required(changeset, [:rejection_reason])
    else
      changeset
    end
  end
end
