defmodule BadgeCollector.Repo.Migrations.AddTypeToActions do
  use Ecto.Migration

  def change do
    alter table(:actions) do
      add :type, :string, null: false, default: ""
    end

    create index(:actions, [:user_id, :type])
  end
end
