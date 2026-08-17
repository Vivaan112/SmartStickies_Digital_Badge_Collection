defmodule BadgeCollectorWeb.SessionController do
  use BadgeCollectorWeb, :controller

  alias BadgeCollector.User
  alias BadgeCollector.Guardian

  def login(conn, %{"email" => email, "password" => password}) do
    case User.access_user(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)
        json(conn, %{token: token})

      :error ->
        conn
        |> put_status(:unathorized)
        |> json(%{error: "incorrect password"})
    end
  end

  def signup(conn, %{"email" => email, "password" => password}) do
    case User.new(email, password) do
      {:ok, user} ->
        {:ok, token, _claims} = Guardian.encode_and_sign(user)
        json(conn, %{token: token})

      {:error, errors} ->
        conn
        |> put_status(:not_acceptable)
        |> json(%{errors: IO.inspect(errors)}) # FIXME
    end
  end
end
