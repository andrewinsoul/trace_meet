defmodule TraceMeet.Repo.Migrations.AddMeetingTypes do
  use Ecto.Migration

  def change do
    alter table(:meetings) do
      add :meeting_type, :string, null: false, default: "general_consultation"
      add :other_meeting_type, :string
    end

    alter table(:advisor_prompt_configurations) do
      add :other_meeting_type, :string
    end

    execute(
      "UPDATE advisor_prompt_configurations SET meeting_type = 'general_consultation' WHERE meeting_type = 'general'",
      "UPDATE advisor_prompt_configurations SET meeting_type = 'general' WHERE meeting_type = 'general_consultation'"
    )
  end
end
