defmodule BadgeCollector.Certificate do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "certificates" do
    field :info, :string
    belongs_to :user, BadgeCollector.User
    belongs_to :badge, BadgeCollector.Badge

    timestamps()
  end

  def changeset(certificate, attrs) do
    certificate
    |> cast(attrs, [:info, :user_id, :badge_id])
    |> validate_required([:user_id, :badge_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:badge_id)
    |> unique_constraint([:user_id, :badge_id])
  end
end
