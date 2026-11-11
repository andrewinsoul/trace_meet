defmodule TraceMeet.Repo.Migrations.MakeUserTimeZoneOptional do
  use Ecto.Migration

  def up do
    execute "UPDATE users SET time_zone = NULL WHERE time_zone = 'Etc/UTC'"

    alter table(:users) do
      modify :time_zone, :string, null: true, default: nil
    end
  end

  def down do
    execute "UPDATE users SET time_zone = 'Etc/UTC' WHERE time_zone IS NULL"

    alter table(:users) do
      modify :time_zone, :string, null: false, default: "Etc/UTC"
    end
  end
end
