defmodule BadgeCollectorWeb.ActionController do
  use BadgeCollectorWeb, :controller

  alias BadgeCollector.{Action, Certifier, Tap}

  @supported_types ~w(login buy_item tap)

  def create(conn, %{"action" => action_type, "data" => data})
      when action_type in @supported_types do
    user = Guardian.Plug.current_resource(conn)

    with :ok <- validate_data(action_type, data),
         {:ok, action} <- Action.new(action_type, data, user.id)
    do
      certificates = Certifier.run(action, user)

      conn
      |> put_status(:created)
      |> json(%{
        action: action_type,
        certificates:
          Enum.map(certificates, &%{badge_id: &1.badge_id, info: &1.info, at: &1.inserted_at})
      })
    else
      {:error, reason} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{errors: inspect(reason)})
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "unsupported action"})
  end

  defp validate_data("login", _data), do: :ok

  defp validate_data("tap", data) do
    case Tap.parse_data(data) do
      {:ok, _tap} -> :ok
      :error -> {:error, ~s(data must be JSON with a "product_id" string and a "tags" list)}
    end
  end

  defp validate_data("buy_item", data) do
    case Action.parse_purchase(%Action{type: "buy_item", data: data}) do
      {:ok, _name, _cost} -> :ok
      :error -> {:error, ~s(data must be "item name|cost")}
    end
  end
end
