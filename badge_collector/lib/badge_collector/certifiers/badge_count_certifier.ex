defmodule BadgeCollector.Certifiers.BadgeCountCertifier do
  @behaviour BadgeCollector.Certifier

  import Ecto.Query

  alias BadgeCollector.Repo
  alias BadgeCollector.{Action, Badge, Certificate, Certifier, User}

  @impl true
  def handles, do: "badge_count"

  # any action can push a user over the line, since the badge that got them
  # there may have come from a login or a purchase
  @impl true
  def relavent_action?(%Action{}), do: true

  @impl true
  def try_certify(%Badge{id: badge_id} = badge, %User{id: user_id}) do
    required = badge |> Certifier.parse_args() |> Certifier.required_count(badge)
    held = non_meta_badges_held(user_id)

    if held >= required do
      Certifier.issue(user_id, badge_id, "#{held} badges collected")
    end
  end

  # badges that count badges do not count toward each other
  @spec non_meta_badges_held(non_neg_integer()) :: non_neg_integer()
  defp non_meta_badges_held(user_id) do
    meta_types = Certifier.meta_types()

    from(c in Certificate,
      join: b in Badge, on: b.id == c.badge_id,
      where: c.user_id == ^user_id and b.unlock_type not in ^meta_types,
      select: count(c.id)
    )
    |> Repo.one
  end
end
