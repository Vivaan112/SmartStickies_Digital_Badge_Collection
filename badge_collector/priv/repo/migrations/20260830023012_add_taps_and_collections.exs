defmodule BadgeCollector.Repo.Migrations.AddTapsAndCollections do
  use Ecto.Migration

  def change do
    alter table(:actions) do
      modify :data, :text, from: :string
    end

    alter table(:badges) do
      add :collection, :string
    end

    create index(:badges, [:collection])
  end
end
