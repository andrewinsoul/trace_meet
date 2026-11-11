defmodule TraceMeet.Transcripts.Transcript do
  use Ecto.Schema
  import Ecto.Changeset

  alias TraceMeet.Meetings.Meeting
  alias TraceMeet.Accounts.User

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id

  schema "transcripts" do
    field :version, :integer
    field :source_type, :string
    field :original_filename, :string
    field :content, :string
    field :cleaned_content, :string
    field :cleaned_segments, :map
    field :selected_at, :utc_datetime_usec

    belongs_to :meeting, Meeting
    belongs_to :advisor, User

    timestamps(type: :utc_datetime_usec)
  end

  def changeset(transcript, attrs) do
    transcript
    |> cast(attrs, [:source_type, :original_filename, :content])
    |> validate_required([:source_type, :content])
    |> validate_inclusion(:source_type, ["paste", "file"])
    |> validate_length(:content, min: 1, max: 2_000_000)
    |> validate_length(:original_filename, max: 255)
  end
end
