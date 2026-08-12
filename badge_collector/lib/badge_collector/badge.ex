defmodule BadgeCollector.Badge do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "badges" do
    field :name, :string
    field :unlock_type, :string # streak, purchase count, disabled, etc...
    field :unlock_args, :string # streak length (days), amount of purchases, nil...
    field :hidden, :boolean, default: false # hide the badge if it has not been unlocked
  end

  def changeset(badge, attrs) do
    badge
    |> cast(attrs, [:name, :unlock_type, :unlock_args, :hidden])
    |> validate_required([:name, :unlock_type])
  end
end
