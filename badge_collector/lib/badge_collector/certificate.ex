defmodule BadgeCollector.Certificate do
  use Ecto.Schema
  import Ecto.Changeset

  alias BadgeCollector.Repo

  @type t :: %__MODULE__{}

  schema "certificates" do
    field :info, :string, default: ""
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

  @spec new(non_neg_integer(), non_neg_integer(), String.t()) :: {:ok, t()} | {:error, [Ecto.Changeset.error(), ...]}
  def new(user_id, badge_id, info \\ "") do
    %__MODULE__{}
    |> changeset(%{user_id: user_id, badge_id: badge_id, info: info})
    |> Repo.insert
    |> case do
      {:ok, cert} -> {:ok, cert}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end
end
