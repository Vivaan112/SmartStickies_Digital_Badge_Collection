defmodule BadgeCollector.Certifiers.LocationCountCertifier do
  @behaviour BadgeCollector.Certifier

  alias BadgeCollector.{Action, Badge, Certifier, Tap, User}

  @impl true
  def handles, do: "location_count"

  @impl true
  def relavent_action?(%Action{type: "tap"} = action) do
    case Tap.parse(action) do
      {:ok, %Tap{location_id: location_id}} -> not is_nil(location_id)
      :error -> false
    end
  end

  def relavent_action?(_action), do: false

  @impl true
  def try_certify(%Badge{id: badge_id} = badge, %User{id: user_id}) do
    required = badge |> Certifier.parse_args() |> Certifier.required_count(badge)

    found =
      user_id
      |> Tap.for_user
      |> Enum.map(& &1.location_id)
      |> Enum.reject(&is_nil/1)
      |> Enum.uniq
      |> length

    if found >= required do
      Certifier.issue(user_id, badge_id, "#{found} different locations")
    end
  end
end
