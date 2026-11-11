defmodule TraceMeet.Repo.Migrations.AddGuardrailScope do
  use Ecto.Migration

  def change do
    alter table(:ai_guardrails) do
      add :scope, :string, null: false, default: "global"
      add :meeting_type, :string
    end

    create index(:ai_guardrails, [:scope, :meeting_type])

    create constraint(:ai_guardrails, :ai_guardrails_valid_scope,
             check: "scope IN ('global', 'meeting_type')"
           )

    create constraint(:ai_guardrails, :ai_guardrails_scope_meeting_type_consistency,
             check:
               "(scope = 'global' AND meeting_type IS NULL) OR (scope = 'meeting_type' AND meeting_type IS NOT NULL)"
           )
  end
end
