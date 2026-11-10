defmodule TraceMeet.AI.AdvisorPrompt do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "advisor_prompt_configurations" do
    field :name, :string
    field :meeting_type, :string, default: "general_consultation"
    field :other_meeting_type, :string
    field :active_version, :integer, default: 1
    field :is_default, :boolean, default: false
    belongs_to :advisor, TraceMeet.Accounts.User
    has_many :versions, TraceMeet.AI.AdvisorPromptVersion
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(prompt, attrs) do
    prompt
    |> cast(attrs, [:advisor_id, :name, :meeting_type, :other_meeting_type, :active_version, :is_default])
    |> validate_required([:advisor_id, :name, :meeting_type, :active_version])
    |> validate_length(:name, max: 100)
    |> validate_inclusion(:meeting_type, TraceMeet.Meetings.Types.values())
    |> validate_other_meeting_type()
    |> validate_length(:meeting_type, max: 80)
    |> unique_constraint([:advisor_id, :name])
    |> foreign_key_constraint(:advisor_id)
  end

  defp validate_other_meeting_type(changeset) do
    if get_field(changeset, :meeting_type) == "other" do
      changeset
      |> validate_required([:other_meeting_type])
      |> validate_length(:other_meeting_type, max: 100)
    else
      put_change(changeset, :other_meeting_type, nil)
    end
  end
end
