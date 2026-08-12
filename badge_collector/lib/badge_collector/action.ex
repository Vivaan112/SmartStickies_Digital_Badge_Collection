defmodule BadgeCollector.Action do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "actions" do
    field :data, :string
    belongs_to :user, BadgeCollector.User

    timestamps()
  end

  def changeset(action, attrs) do
    action
    |> cast(attrs, [:data, :user_id])
    |> validate_required([:data, :user_id])
    |> foreign_key_constraint(:user_id)
  end
end
