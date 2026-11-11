defmodule TraceMeet.Repo.Migrations.SimplifyAdvisorPromptConfigurations do
  use Ecto.Migration

  def up do
    alter table(:advisor_prompt_configurations) do
      add :instructions, :text
    end

    execute("""
    UPDATE advisor_prompt_configurations AS prompt
    SET instructions = COALESCE((
      SELECT version.instructions
      FROM advisor_prompt_versions AS version
      WHERE version.advisor_prompt_id = prompt.id
        AND version.version = prompt.active_version
    ), '')
    """)

    alter table(:advisor_prompt_configurations) do
      modify :instructions, :text, null: false
      remove :active_version
    end

    alter table(:processing_runs) do
      remove :advisor_prompt_version
    end

    drop table(:advisor_prompt_versions)
  end

  def down do
    create table(:advisor_prompt_versions, primary_key: false) do
      add :id, :binary_id, primary_key: true

      add :advisor_prompt_id,
          references(:advisor_prompt_configurations, type: :binary_id, on_delete: :delete_all),
          null: false

      add :version, :integer, null: false
      add :instructions, :text, null: false
      add :sha256, :string, null: false
      timestamps(type: :utc_datetime_usec, updated_at: false)
    end

    create unique_index(:advisor_prompt_versions, [:advisor_prompt_id, :version])

    alter table(:advisor_prompt_configurations) do
      add :active_version, :integer, null: false, default: 1
    end

    alter table(:processing_runs) do
      add :advisor_prompt_version, :integer
    end

    execute("""
    INSERT INTO advisor_prompt_versions
      (id, advisor_prompt_id, version, instructions, sha256, inserted_at)
    SELECT
      gen_random_uuid(),
      id,
      1,
      instructions,
      encode(sha256(convert_to(instructions, 'UTF8')), 'hex'),
      NOW()
    FROM advisor_prompt_configurations
    """)

    execute("""
    UPDATE processing_runs
    SET advisor_prompt_version = 1
    WHERE advisor_prompt_id IS NOT NULL
    """)
  end
end
