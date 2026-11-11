defmodule TraceMeet.Extractions.Risk do
  use Ecto.Schema
  import Ecto.Changeset

  alias TraceMeet.Accounts.User
  alias TraceMeet.Clients.Client
  alias TraceMeet.Meetings.Meeting
  alias TraceMeet.Extractions.ExtractionProposal

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "risks" do
    field :title, :string
    field :description, :string
    field :owner, :string
    field :due_date, :date

    belongs_to :advisor, User
    belongs_to :client, Client
    belongs_to :meeting, Meeting
    belongs_to :extraction_proposal, ExtractionProposal

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(record, attrs) do
    record
    |> cast(attrs, [
      :advisor_id,
      :client_id,
      :meeting_id,
      :extraction_proposal_id,
      :title,
      :description,
      :owner,
      :due_date
    ])
    |> validate_required([
      :advisor_id,
      :client_id,
      :meeting_id,
      :extraction_proposal_id,
      :title,
      :description
    ])
    |> validate_length(:title, max: 255)
    |> foreign_key_constraint(:advisor_id)
    |> foreign_key_constraint(:client_id)
    |> foreign_key_constraint(:meeting_id)
    |> foreign_key_constraint(:extraction_proposal_id)
    |> unique_constraint(:extraction_proposal_id)
  end
end
