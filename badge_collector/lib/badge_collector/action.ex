defmodule BadgeCollector.Action do
  use Ecto.Schema
  import Ecto.Changeset

  alias BadgeCollector.Repo

  @type t :: %__MODULE__{}

  schema "actions" do
    field :type, :string
    field :data, :string
    belongs_to :user, BadgeCollector.User

    timestamps()
  end

  def changeset(action, attrs) do
    action
    |> cast(attrs, [:type, :data, :user_id])
    |> validate_required([:type, :data, :user_id])
    |> foreign_key_constraint(:user_id)
  end

  def new(type, data, user_id) do
    %__MODULE__{}
    |> changeset(%{type: type, data: data, user_id: user_id})
    |> Repo.insert
    |> case do
      {:ok, action} -> {:ok, action}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  @spec parse_purchase(t()) :: {:ok, String.t(), float()} | :error
  def parse_purchase(%__MODULE__{type: "buy_item", data: data}) when is_binary(data) do
    with [name, cost] <- String.split(data, "|", parts: 2),
         {cost, ""} <- Float.parse(String.trim(cost))
    do
      {:ok, String.trim(name), cost}
    else
      _ -> :error
    end
  end
  def parse_purchase(_action), do: :error
end
