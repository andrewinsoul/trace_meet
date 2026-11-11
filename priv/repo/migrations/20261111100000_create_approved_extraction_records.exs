defmodule TraceMeet.Repo.Migrations.CreateApprovedExtractionRecords do
  use Ecto.Migration

  @tables ~w(decisions action_items commitments risks unresolved_questions)

  def change do
    Enum.each(@tables, fn table ->
      create table(table, primary_key: false) do
        add :id, :binary_id, primary_key: true
        add :advisor_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false
        add :client_id, references(:clients, type: :binary_id, on_delete: :delete_all), null: false
        add :meeting_id, references(:meetings, type: :binary_id, on_delete: :delete_all), null: false
        add :extraction_proposal_id,
            references(:extraction_proposals, type: :binary_id, on_delete: :restrict), null: false
        add :title, :string, null: false
        add :description, :text, null: false
        add :owner, :string
        add :due_date, :date
        timestamps(type: :utc_datetime_usec)
      end

      create unique_index(table, [:extraction_proposal_id])
      create index(table, [:advisor_id, :inserted_at])
      create index(table, [:client_id, :inserted_at])
      create index(table, [:meeting_id])
    end)
  end
end
