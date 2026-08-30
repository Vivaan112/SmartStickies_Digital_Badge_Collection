alias BadgeCollector.Repo
alias BadgeCollector.{Badge, User}

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

upsert_user.("jane@example.com", "correcthorsebatterystaple")
upsert_user.("john@example.com", "hunter22222")

# unlock_args is JSON. tag_count takes an optional "tag" (omit it to count any
# product) and an optional "context" filter, plus a required "count".
badges = [
  # --- category badges -------------------------------------------------------
  %{name: "Dairy Explorer", collection: "core",
    unlock_type: "tag_count", unlock_args: ~s({"tag":"dairy","count":3})},
  %{name: "Chocolate Collector", collection: "core",
    unlock_type: "tag_count", unlock_args: ~s({"tag":"chocolate","count":5})},
  %{name: "Beverage Explorer", collection: "core",
    unlock_type: "tag_count", unlock_args: ~s({"tag":"beverage","count":5})},
  %{name: "Healthy Choices", collection: "core",
    unlock_type: "tag_count", unlock_args: ~s({"tag":"healthy","count":5})},
  %{name: "Snack Collector", collection: "core",
    unlock_type: "tag_count", unlock_args: ~s({"tag":"snack","count":5})},
  %{name: "Sweet Tooth", collection: "core",
    unlock_type: "tag_count", unlock_args: ~s({"tag":"sweet","count":5})},
  %{name: "Coffee Explorer", collection: "core",
    unlock_type: "tag_count", unlock_args: ~s({"tag":"coffee","count":3})},
  %{name: "Foodie", collection: "core",
    unlock_type: "tag_count", unlock_args: ~s({"tag":"food","count":10})},
  %{name: "Fresh Finds", collection: "core",
    unlock_type: "tag_count", unlock_args: ~s({"tag":"fresh","count":5})},

  # --- product and context badges --------------------------------------------
  %{name: "Product Hunter", collection: "core",
    unlock_type: "tag_count", unlock_args: ~s({"count":10})},
  %{name: "Shopping Explorer", collection: "core",
    unlock_type: "tag_count", unlock_args: ~s({"context":"shopping","count":5})},
  %{name: "Rare Find", collection: "core", hidden: true,
    unlock_type: "tag_count", unlock_args: ~s({"tag":"rare_find","count":1})},

  # --- raw tap counts --------------------------------------------------------
  %{name: "First Tap", collection: "core",
    unlock_type: "tap_count", unlock_args: ~s({"count":1})},
  %{name: "Tap Master", collection: "core",
    unlock_type: "tap_count", unlock_args: ~s({"count":10})},
  %{name: "Tap Champion", collection: "core",
    unlock_type: "tap_count", unlock_args: ~s({"count":25})},

  # --- locations -------------------------------------------------------------
  %{name: "Explorer", collection: "core",
    unlock_type: "location_count", unlock_args: ~s({"count":5})},
  %{name: "World Explorer", collection: "core",
    unlock_type: "location_count", unlock_args: ~s({"count":10})},

  # --- meta badges, deliberately outside "core" so Completionist is reachable -
  %{name: "Collection Starter",
    unlock_type: "badge_count", unlock_args: ~s({"count":3})},
  %{name: "Master Collector",
    unlock_type: "badge_count", unlock_args: ~s({"count":10})},
  %{name: "Completionist",
    unlock_type: "collection_complete", unlock_args: ~s({"collection":"core"})}
]

for attrs <- badges, do: upsert_badge.(attrs)

IO.puts("seeded #{length(badges)} badges")
