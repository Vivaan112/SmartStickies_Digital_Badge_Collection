defmodule BadgeCollector.Certifiers.CollectionCertifier do
  @behaviour BadgeCollector.Certifier

  import Ecto.Query

  alias BadgeCollector.Repo
  alias BadgeCollector.{Action, Badge, Certificate, Certifier, User}

  @impl true
  def handles, do: "collection_complete"

  @impl true
  def relavent_action?(%Action{}), do: true

  @impl true
  def try_certify(%Badge{id: badge_id} = badge, %User{id: user_id}) do
    collection = badge |> Certifier.parse_args() |> Map.get("collection")

    with false <- is_nil(collection),
         total when total > 0 <- badges_in(collection),
         ^total <- held_in(collection, user_id) do
      Certifier.issue(user_id, badge_id, "completed the #{collection} collection")
    else
      _ -> nil
    end
  end

  @spec badges_in(String.t()) :: non_neg_integer()
  defp badges_in(collection) do
    from(b in Badge, where: b.collection == ^collection)
    |> Repo.aggregate(:count)
  end

  @spec held_in(String.t(), non_neg_integer()) :: non_neg_integer()
  defp held_in(collection, user_id) do
    from(c in Certificate,
      join: b in Badge, on: b.id == c.badge_id,
      where: c.user_id == ^user_id and b.collection == ^collection,
      select: count(c.id)
    )
    |> Repo.one
  end
end
