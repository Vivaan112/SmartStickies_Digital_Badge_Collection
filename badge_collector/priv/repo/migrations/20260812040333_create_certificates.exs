defmodule BadgeCollector.Repo.Migrations.CreateCertificates do
  use Ecto.Migration

  def change do
    create table(:certificates) do
      add :info, :string
      add :user_id, references(:users, on_delete: :delete_all), null: false
      add :badge_id, references(:badges, on_delete: :restrict), null: false
      timestamps()
    end
    create index(:certificates, [:user_id])
    create index(:certificates, [:badge_id])
    create unique_index(:certificates, [:user_id, :badge_id])
  end
end
