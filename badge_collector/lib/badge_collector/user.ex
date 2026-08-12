defmodule BadgeCollector.User do
  use Ecto.Schema
  import Ecto.Changeset
  import Pbkdf2

  @type t :: %__MODULE__{}

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hash, :string, redact: true
    has_many :certificates, BadgeCollector.Certificate
    has_many :actions, BadgeCollector.Action

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
    |> validate_format(:email, ~r/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i)
    |> unique_constraint(:email)
    |> put_hash
  end

  #TODO: only modify if old password was provided
  @spec put_hash(Ecto.Changeset.t(t())) :: Ecto.Changeset.t(t())
  defp put_hash(changeset) do
    case get_change(changeset, :password) do
      nil -> changeset

      password ->
        changeset
        |> put_change(:hash, hash_pwd_salt(password))
        |> delete_change(:password)
    end
  end
end
