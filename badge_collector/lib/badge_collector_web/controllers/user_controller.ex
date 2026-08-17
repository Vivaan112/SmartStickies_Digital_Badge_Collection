defmodule BadgeCollectorWeb.UserController do
  use BadgeCollectorWeb, :controller
\
  alias BadgeCollector.User

  def delete(conn, _params) do
    %User{:id => id} = Guardian.Plug.current_resource(conn)
    case User.delete_user(id) do
      :ok -> send_resp(conn, 204, "")
      {:error, :not_found} ->send_resp(conn, 500, "user not found")
    end
  end
end
