defmodule BadgeCollector.User do
  use Ecto.Schema
  import Ecto.{Changeset, Query}
  import Pbkdf2

  alias BadgeCollector.Repo
  alias BadgeCollector.{Action, Certificate, Badge}


  @type t :: %__MODULE__{}

  schema "users" do
    field :email, :string
    field :password, :string, virtual: true, redact: true
    field :hash, :string, redact: true
    has_many :certificates, Certificate
    has_many :actions, Action

    timestamps()
  end

  def changeset(user, attrs) do
    user
    |> cast(attrs, [:email, :password])
    |> validate_required([:email, :password])
    |> validate_format(:password, ~r/^.{1,2048}$/)
    |> validate_format(:email, ~r/\b[A-Z0-9._%+-]+@[A-Z0-9.-]+\.[A-Z]{2,}\b/i)
    |> unique_constraint(:email)
    |> put_hash
  end

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

  @spec get_user(non_neg_integer()) :: t() | nil
  def get_user(id), do: Repo.get(__MODULE__, id)

  @spec new(binary(), binary()) :: {:ok, t()} | {:error, [Ecto.Changeset.error(), ...]}
  def new(email, password) do
    %__MODULE__{}
    |> changeset(%{email: email, password: password})
    |> Repo.insert
    |> case do
      {:ok, user} -> {:ok, user}
      {:error, changeset} -> {:error, changeset.errors}
    end
  end

  @spec access_user(binary(), binary()) :: {:ok, t()} | :error
  def access_user(email, password) do
    case Repo.one(from user in __MODULE__, where: user.email == ^email) do
      nil ->
        Pbkdf2.no_user_verify()
        :error
      %__MODULE__{hash: hash} = user ->
        if Pbkdf2.verify_pass(password, hash), do: {:ok, user}, else: :error
    end
  end

  @spec delete_user(non_neg_integer()) :: :ok | {:error, :not_found}
  def delete_user(id) do
    with user when not is_nil(user) <- Repo.get(__MODULE__, id),
         changeset <- Ecto.Changeset.change(user),
         {:ok, _user} <- Repo.delete(changeset)
      do
        :ok
      else
        nil -> {:error, :not_found}
      end
  end

  @spec earned_badges(t()) :: [Badge.t()]
  def earned_badges(_user = %__MODULE__{id: user_id}) do
    from(b in Badge,
      join: c in Certificate, on: c.badge_id == b.id and c.user_id == ^user_id,
      select: merge(b, %{certified_at: c.inserted_at, cert_info: c.info})
    ) |> Repo.all
  end

  @spec unearned_badges(t(), boolean()) :: [Badge.t()]
  def unearned_badges(_user = %__MODULE__{id: user_id}, ignore_hidden \\ false) do
    query =
      from(b in Badge,
        left_join: c in Certificate, on: c.badge_id == b.id and c.user_id == ^user_id,
        where: is_nil(c.id),
        select: b
      )

    query = if ignore_hidden, do: query, else: from(b in query, where: b.hidden == false)

    Repo.all(query)
  end

  @spec exists?(t()) :: boolean()
  def exists?(_user = %__MODULE__{id: user_id}), do: !!Repo.get(__MODULE__, user_id)
end
