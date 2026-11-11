defmodule TraceMeet.AI.GuardrailVersion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "ai_guardrail_versions" do
    field :version, :integer
    field :instruction, :string
    field :sha256, :string
    belongs_to :guardrail, TraceMeet.AI.Guardrail
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(version, attrs) do
    version
    |> cast(attrs, [:version, :instruction, :sha256])
    |> validate_required([:guardrail_id, :version, :instruction, :sha256])
    |> unique_constraint([:guardrail_id, :version])
    |> foreign_key_constraint(:guardrail_id)
  end
end
