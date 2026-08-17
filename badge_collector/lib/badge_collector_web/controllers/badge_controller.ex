defmodule BadgeCollectorWeb.BadgeController do
  use BadgeCollectorWeb, :controller

  alias BadgeCollector.{User, Badge}

  def show(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    json(conn, %{
      "acquired" => user |> User.earned_badges |> Enum.each(&Badge.to_display_information/1),
      "missing" => user |> User.unearned_badges |> Enum.each(&Badge.to_display_information/1)
    })
  end
end
