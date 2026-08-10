defmodule BadgeCollector.Repo do
  use Ecto.Repo,
    otp_app: :badge_collector,
    adapter: Ecto.Adapters.Postgres
end
