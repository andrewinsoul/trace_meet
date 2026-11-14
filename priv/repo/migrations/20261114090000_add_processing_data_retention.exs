defmodule TraceMeet.Repo.Migrations.AddProcessingDataRetention do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :processing_data_retention_days, :integer, null: false, default: 30
    end

    create constraint(:users, :users_processing_data_retention_days_check,
             check: "processing_data_retention_days IN (7, 14, 30, 60, 90)"
           )
  end
end
