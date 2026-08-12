defmodule BadgeCollector.Repo.Migrations.CreateBadges do
  use Ecto.Migration

  def change do
    create table(:badges) do
      add :name, :string, null: false
      add :unlock_type, :string, null: false
      add :unlock_args, :string
      add :hidden, :boolean, default: false, null: false
    end
  end
end
