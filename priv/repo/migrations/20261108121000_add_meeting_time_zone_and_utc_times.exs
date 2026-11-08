defmodule TraceMeet.Repo.Migrations.AddMeetingTimeZoneAndUtcTimes do
  use Ecto.Migration

  def up do
    alter table(:meetings) do
      add :time_zone, :string, null: false, default: "Etc/UTC"
    end

    execute """
    ALTER TABLE meetings
      ALTER COLUMN scheduled_at TYPE timestamptz USING scheduled_at AT TIME ZONE 'UTC',
      ALTER COLUMN started_at TYPE timestamptz USING started_at AT TIME ZONE 'UTC',
      ALTER COLUMN ended_at TYPE timestamptz USING ended_at AT TIME ZONE 'UTC'
    """
  end

  def down do
    execute """
    ALTER TABLE meetings
      ALTER COLUMN scheduled_at TYPE timestamp without time zone USING scheduled_at AT TIME ZONE 'UTC',
      ALTER COLUMN started_at TYPE timestamp without time zone USING started_at AT TIME ZONE 'UTC',
      ALTER COLUMN ended_at TYPE timestamp without time zone USING ended_at AT TIME ZONE 'UTC'
    """

    alter table(:meetings) do
      remove :time_zone
    end
  end
end
