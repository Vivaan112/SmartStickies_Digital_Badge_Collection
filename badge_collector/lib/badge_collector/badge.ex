defmodule BadgeCollector.Badge do
  use Ecto.Schema
  import Ecto.Changeset

  @type t :: %__MODULE__{}

  schema "badges" do
    field :name, :string
    field :unlock_type, :string # streak, purchase count, disabled, etc...
    field :unlock_args, :string # streak length (days), amount of purchases, nil...
    field :hidden, :boolean, default: false # hide the badge if it has not been unlocked
    field :certified_at, :naive_datetime, virtual: true
    field :cert_info, :string, virtual: true
  end

  def changeset(badge, attrs) do
    badge
    |> cast(attrs, [:name, :unlock_type, :unlock_args, :hidden])
    |> validate_required([:name, :unlock_type])
  end

  @spec to_display_information(t()) :: map()
  def to_display_information(%__MODULE__{} = badge) do
    %{
      name: badge.name,
      unlock_type: badge.unlock_type,
      unlock_args: badge.unlock_args,
      certified_at: badge.certified_at,
      cert_info: badge.cert_info,
      earned?: not is_nil(badge.certified_at)
    }
  end
end
