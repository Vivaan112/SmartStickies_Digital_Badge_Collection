defmodule BadgeCollector.Certifiers.TagCountCertifier do
  @behaviour BadgeCollector.Certifier

  alias BadgeCollector.{Action, Badge, Certifier, Tap, User}

  @impl true
  def handles, do: "tag_count"

  @impl true
  def relavent_action?(%Action{type: "tap"} = action), do: match?({:ok, _tap}, Tap.parse(action))
  def relavent_action?(_action), do: false

  @impl true
  def try_certify(%Badge{id: badge_id} = badge, %User{id: user_id}) do
    args = Certifier.parse_args(badge)
    required = Certifier.required_count(args, badge)
    tag = Map.get(args, "tag")
    context = Map.get(args, "context")

    found =
      user_id
      |> Tap.for_user
      |> Enum.filter(&(Tap.tagged?(&1, tag) and Tap.in_context?(&1, context)))
      |> Enum.map(& &1.product_id)
      |> Enum.uniq
      |> length

    if found >= required do
      Certifier.issue(user_id, badge_id, describe(found, tag, context))
    end
  end

  @spec describe(non_neg_integer(), String.t() | nil, String.t() | nil) :: String.t()
  defp describe(count, tag, context) do
    subject = if tag, do: "#{tag} products", else: "products"
    where = if context, do: " while #{context}", else: ""

    "#{count} different #{subject}#{where}"
  end
end
