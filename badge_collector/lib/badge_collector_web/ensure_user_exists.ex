defmodule BadgeCollectorWeb.EnsureUserExists do
  import Plug.Conn

  alias BadgeCollector.User

  def init(opts), do: opts

  def call(conn, _opts) do
    user = Guardian.Plug.current_resource(conn)
    if User.exists?(user) do
      conn #|> assign(:current_user, user)
    else
      conn |> send_resp(401, "unauthorized") |> halt
    end
  end
end
