defmodule TraceMeet.Extractions.ExtractionProposalSource do
  use Ecto.Schema
  import Ecto.Changeset

  alias TraceMeet.Extractions.{ExtractionProposal, ChunkExtraction}

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "extraction_proposal_sources" do
    belongs_to :extraction_proposal, ExtractionProposal
    belongs_to :chunk_extraction, ChunkExtraction
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(source, attrs) do
    source
    |> cast(attrs, [])
    |> validate_required([:extraction_proposal_id, :chunk_extraction_id])
    |> unique_constraint([:extraction_proposal_id, :chunk_extraction_id], name: :extraction_proposal_sources_unique_index)
    |> foreign_key_constraint(:extraction_proposal_id)
    |> foreign_key_constraint(:chunk_extraction_id)
  end
end
