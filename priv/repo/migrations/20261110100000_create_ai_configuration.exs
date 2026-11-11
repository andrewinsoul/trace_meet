defmodule TraceMeet.Repo.Migrations.CreateAiConfiguration do
  use Ecto.Migration

  def change do
    create table(:ai_guardrails, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :key, :string, null: false
      add :name, :string, null: false
      add :active_version, :integer, null: false, default: 1
      timestamps(type: :utc_datetime_usec)
    end

    create unique_index(:ai_guardrails, [:key])

    create table(:ai_guardrail_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :guardrail_id, references(:ai_guardrails, type: :binary_id, on_delete: :delete_all), null: false
      add :version, :integer, null: false
      add :instruction, :text, null: false
      add :sha256, :string, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:ai_guardrail_versions, [:guardrail_id, :version])

    create table(:advisor_prompt_configurations, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :advisor_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :meeting_type, :string, null: false, default: "general"
      add :active_version, :integer, null: false, default: 1
      add :is_default, :boolean, null: false, default: false
      timestamps(type: :utc_datetime_usec)
    end

    create index(:advisor_prompt_configurations, [:advisor_id])
    create unique_index(:advisor_prompt_configurations, [:advisor_id, :name])
    create unique_index(:advisor_prompt_configurations, [:advisor_id],
      where: "is_default = TRUE", name: :advisor_prompt_configurations_one_default_index)

    create table(:advisor_prompt_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true
      add :advisor_prompt_id, references(:advisor_prompt_configurations, type: :binary_id, on_delete: :delete_all), null: false
      add :version, :integer, null: false
      add :instructions, :text, null: false
      add :sha256, :string, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:advisor_prompt_versions, [:advisor_prompt_id, :version])

    alter table(:processing_runs) do
      add :guardrails_snapshot, :map, null: false, default: %{}
      add :advisor_prompt_id, references(:advisor_prompt_configurations, type: :binary_id, on_delete: :nilify_all)
      add :advisor_prompt_version, :integer
      add :advisor_prompt_snapshot, :text, null: false, default: ""
      add :advisor_prompt_sha256, :string
    end
  end
end
