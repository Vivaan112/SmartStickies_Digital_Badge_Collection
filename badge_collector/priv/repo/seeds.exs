alias BadgeCollector.Repo
alias BadgeCollector.{Action, Badge, Certifier, User}

upsert_user = fn email, password ->
  case Repo.get_by(User, email: email) do
    nil ->
      %User{}
      |> User.changeset(%{email: email, password: password})
      |> Repo.insert!()

    existing ->
      existing
  end
end

upsert_badge = fn attrs ->
  case Repo.get_by(Badge, name: attrs.name) do
    nil -> %Badge{} |> Badge.changeset(attrs) |> Repo.insert!()
    existing -> existing
  end
end

jane = upsert_user.("jane@example.com", "correcthorsebatterystaple")
_john = upsert_user.("john@example.com", "hunter22222")

# unlock_type must match a certifier's handles/0, or the badge can never be
# earned. login_streak and purchase_count take whole numbers; total_spent is
# read with String.to_float/1, so it needs a decimal point.
upsert_badge.(%{name: "Showed Up", unlock_type: "login_streak", unlock_args: "1"})
upsert_badge.(%{name: "Three Day Habit", unlock_type: "login_streak", unlock_args: "3"})
upsert_badge.(%{name: "One Week Streak", unlock_type: "login_streak", unlock_args: "7"})
upsert_badge.(%{name: "First Purchase", unlock_type: "purchase_count", unlock_args: "1"})
upsert_badge.(%{name: "Bought Ten Items", unlock_type: "purchase_count", unlock_args: "10"})
upsert_badge.(%{name: "Spent Fifty", unlock_type: "total_spent", unlock_args: "50.0"})

# hidden badges stay out of the "missing" list until they are earned
upsert_badge.(%{
  name: "Mystery Collector",
  unlock_type: "purchase_count",
  unlock_args: "25",
  hidden: true
})

# no certifier claims this unlock_type, so it can never be earned - it exists to
# prove the dispatch loop skips unknown types instead of crashing
upsert_badge.(%{
  name: "Retired Badge",
  unlock_type: "disabled",
  unlock_args: nil,
  hidden: true
})

# --- give jane some history so the API has something to show ------------------

if Repo.aggregate(Action, :count) == 0 do
  for days_ago <- 6..1//-1 do
    at =
      NaiveDateTime.utc_now()
      |> NaiveDateTime.add(-days_ago * 86_400, :second)
      |> NaiveDateTime.truncate(:second)

    Repo.insert!(%Action{
      type: "login",
      data: "",
      user_id: jane.id,
      inserted_at: at,
      updated_at: at
    })
  end

  for {item, cost} <- [
        {"blue sticker", "4.50"},
        {"gold star", "12.00"},
        {"holographic cat", "21.25"},
        {"enamel pin", "15.00"}
      ] do
    Repo.insert!(%Action{type: "buy_item", data: "#{item}|#{cost}", user_id: jane.id})
  end

  # today's login closes a seven day streak; run it through the real pipeline
  today = Repo.insert!(%Action{type: "login", data: "", user_id: jane.id})
  earned = Certifier.run(today, jane)

  IO.puts("seeded #{jane.email} with #{length(earned)} badge(s) from her login streak")

  purchase = Repo.insert!(%Action{type: "buy_item", data: "mystery box|9.99", user_id: jane.id})
  earned = Certifier.run(purchase, jane)

  IO.puts("seeded #{jane.email} with #{length(earned)} badge(s) from her purchases")
end
