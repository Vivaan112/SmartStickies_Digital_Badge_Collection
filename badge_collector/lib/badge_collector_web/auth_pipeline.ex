defmodule BadgeCollectorWeb.AuthPipeline do
  use Guardian.Plug.Pipeline,
  otp_app: :badge_collector,
  module: BadgeCollector.Guardian,
  error_handler: BadgeCollectorWeb.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
  plug BadgeCollectorWeb.EnsureUserExists
end
