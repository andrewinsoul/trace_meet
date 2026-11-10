defmodule TraceMeet.Extractions.ExtractionProposalReview do
  use Ecto.Schema
  import Ecto.Changeset

  alias TraceMeet.Accounts.User
  alias TraceMeet.Extractions.ExtractionProposal

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  @actions ["approved", "rejected", "edited"]

  schema "extraction_proposal_reviews" do
    field :action, :string
    field :previous_values, :map
    field :new_values, :map
    field :notes, :string
    belongs_to :extraction_proposal, ExtractionProposal
    belongs_to :advisor, User
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(review, attrs) do
    review
    |> cast(attrs, [:action, :previous_values, :new_values, :notes])
    |> validate_required([:extraction_proposal_id, :advisor_id, :action])
    |> validate_inclusion(:action, @actions)
    |> foreign_key_constraint(:extraction_proposal_id)
    |> foreign_key_constraint(:advisor_id)
    |> check_constraint(:action, name: :extraction_proposal_reviews_action_check)
  end
end
