defmodule TraceMeet.Extractions.ExtractionProposalEvidence do
  use Ecto.Schema
  import Ecto.Changeset

  alias TraceMeet.Extractions.ExtractionProposal

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "extraction_proposal_evidence" do
    field :segment_id, :string
    field :source_start, :integer
    field :source_end, :integer
    field :speaker, :string
    field :timestamp, :string
    field :quote, :string
    belongs_to :extraction_proposal, ExtractionProposal
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(evidence, attrs) do
    evidence
    |> cast(attrs, [:segment_id, :source_start, :source_end, :speaker, :timestamp, :quote])
    |> validate_required([:extraction_proposal_id, :segment_id, :quote])
    |> foreign_key_constraint(:extraction_proposal_id)
  end
end
