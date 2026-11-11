defmodule TraceMeet.Repo.Migrations.AddUserTimeZone do
  use Ecto.Migration

  def change do
    alter table(:users) do
      add :time_zone, :string, null: false, default: "Etc/UTC"
    end
  end
end
