alias BadgeCollector.Repo
alias BadgeCollector.{User, Badge, Certificate, Action}

user1 =
  case Repo.get_by(User, email: "jane@example.com") do
    nil ->
      %User{}
      |> User.changeset(%{email: "jane@example.com", password: "correcthorsebatterystaple"})
      |> Repo.insert!()

    existing -> existing
  end

user2 =
  case Repo.get_by(User, email: "john@example.com") do
    nil ->
      %User{}
      |> User.changeset(%{email: "john@example.com", password: "hunter22222"})
      |> Repo.insert!()

    existing -> existing
  end

badge_streak =
  %Badge{}
  |> Badge.changeset(%{name: "1 Week streak", unlock_type: "streak", unlock_args: "7"})
  |> Repo.insert!()

badge_purchase =
  %Badge{}
  |> Badge.changeset(%{name: "Bought ten items", unlock_type: "purchase_count", unlock_args: "10"})
  |> Repo.insert!()

badge_disabled =
  %Badge{}
  |> Badge.changeset(%{name: "Retired Badge", unlock_type: "disabled", unlock_args: nil, hidden: true})
  |> Repo.insert!()

badge_default_hidden =
  %Badge{}
  |> Badge.changeset(%{name: "Mystery Badge", unlock_type: "streak", unlock_args: "30"})
  |> Repo.insert!()
