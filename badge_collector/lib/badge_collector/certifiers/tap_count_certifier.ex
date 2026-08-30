defmodule BadgeCollector.Certifiers.TapCountCertifier do
  @behaviour BadgeCollector.Certifier

  import Ecto.Query

  alias BadgeCollector.Repo
  alias BadgeCollector.{Action, Badge, Certifier, User}

  @impl true
  def handles, do: "tap_count"

  @impl true
  def relavent_action?(%Action{type: "tap"}), do: true
  def relavent_action?(_action), do: false

  @impl true
  def try_certify(%Badge{id: badge_id} = badge, %User{id: user_id}) do
    required = badge |> Certifier.parse_args() |> Certifier.required_count(badge)
    taps = tap_count(user_id)

    if taps >= required do
      Certifier.issue(user_id, badge_id, "#{taps} taps")
    end
  end

  # every tap counts, including repeats of the same sticker and payloads we
  # could not parse
  @spec tap_count(non_neg_integer()) :: non_neg_integer()
  defp tap_count(user_id) do
    from(a in Action, where: a.user_id == ^user_id and a.type == "tap")
    |> Repo.aggregate(:count)
  end
end
