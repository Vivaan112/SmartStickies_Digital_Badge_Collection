defmodule BadgeCollectorWeb.AuthErrorHandler do
  import Plug.Conn

  @behaviour Guardian.Plug.ErrorHandler

  @impl true
  def auth_error(conn, {type, _reason}, _opts) do
    conn
    |> put_status(:unauthorized)
    |> Phoenix.Controller.json(%{error: to_string(type)})
  end
end
