defmodule TraceMeet.AI.Guardrail do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "ai_guardrails" do
    field :key, :string
    field :name, :string
    field :active_version, :integer, default: 1
    field :scope, :string, default: "global"
    field :meeting_type, :string
    has_many :versions, TraceMeet.AI.GuardrailVersion
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(guardrail, attrs) do
    guardrail
    |> cast(attrs, [:key, :name, :active_version, :scope, :meeting_type])
    |> validate_required([:key, :name, :active_version, :scope])
    |> validate_inclusion(:scope, ["global", "meeting_type"])
    |> validate_scope_meeting_type()
    |> unique_constraint(:key)
  end

  defp validate_scope_meeting_type(changeset) do
    case get_field(changeset, :scope) do
      "global" -> put_change(changeset, :meeting_type, nil)
      "meeting_type" -> validate_required(changeset, [:meeting_type])
      _ -> changeset
    end
  end
end
