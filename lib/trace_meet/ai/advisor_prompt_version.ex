defmodule TraceMeet.AI.AdvisorPromptVersion do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "advisor_prompt_versions" do
    field :version, :integer
    field :instructions, :string
    field :sha256, :string
    belongs_to :advisor_prompt, TraceMeet.AI.AdvisorPrompt
    timestamps(type: :utc_datetime_usec, updated_at: false)
  end

  def changeset(version, attrs) do
    version
    |> cast(attrs, [:advisor_prompt_id, :version, :instructions, :sha256])
    |> validate_required([:advisor_prompt_id, :version, :instructions, :sha256])
    |> unique_constraint([:advisor_prompt_id, :version])
    |> foreign_key_constraint(:advisor_prompt_id)
  end
end
