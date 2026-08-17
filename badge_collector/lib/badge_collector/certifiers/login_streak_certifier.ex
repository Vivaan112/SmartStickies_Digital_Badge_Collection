defmodule BadgeCollector.Certifiers.LoginStreakCertifier do
  @behaviour BadgeCollector.Certifier

  import Ecto.Query

  alias BadgeCollector.Repo
  alias BadgeCollector.{Action, Badge, Certifier, User}

  @impl true
  def handles, do: "login_streak"

  @impl true
  def relavent_action?(%Action{type: "login"}), do: true
  def relavent_action?(_action), do: false

  @impl true
  def try_certify(%Badge{id: badge_id, unlock_args: unlock_args}, %User{id: user_id}) do
    required = String.to_integer(unlock_args || "1")
    streak = current_streak(user_id)

    if streak >= required do
      Certifier.issue(user_id, badge_id, "#{streak} day login streak")
    end
  end

  @spec current_streak(non_neg_integer()) :: non_neg_integer()
  defp current_streak(user_id) do
    from(a in Action,
      where: a.user_id == ^user_id and a.type == "login",
      select: a.inserted_at
    )
    |> Repo.all
    |> Enum.map(&NaiveDateTime.to_date/1)
    |> Enum.uniq
    |> Enum.sort({:desc, Date})
    |> count_consecutive
  end

  @spec count_consecutive([Date.t()]) :: non_neg_integer()
  defp count_consecutive([]), do: 0

  defp count_consecutive([most_recent | earlier]) do
    earlier
    |> Enum.reduce_while({1, most_recent}, fn day, {count, previous} ->
      if Date.diff(previous, day) == 1,
        do: {:cont, {count + 1, day}},
        else: {:halt, {count, day}}
    end)
    |> elem(0)
  end
end
