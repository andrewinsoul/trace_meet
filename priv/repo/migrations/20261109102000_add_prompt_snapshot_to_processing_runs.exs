defmodule TraceMeet.Repo.Migrations.AddPromptSnapshotToProcessingRuns do
  use Ecto.Migration

  def up do
    alter table(:processing_runs) do
      add :prompt_version, :string
      add :prompt_snapshot, :text
      add :prompt_sha256, :string
      add :model, :string
      add :cleaned_content, :text
      add :cleaned_segments, :map
    end

    execute """
    UPDATE processing_runs
    SET prompt_version = 'legacy',
        prompt_snapshot = '',
        prompt_sha256 = 'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
        model = 'legacy'
    """

    alter table(:processing_runs) do
      modify :prompt_version, :string, null: false
      modify :prompt_snapshot, :text, null: false
      modify :prompt_sha256, :string, null: false
      modify :model, :string, null: false
    end
  end

  def down do
    alter table(:processing_runs) do
      remove :prompt_version
      remove :prompt_snapshot
      remove :prompt_sha256
      remove :model
      remove :cleaned_content
      remove :cleaned_segments
    end
  end
end
