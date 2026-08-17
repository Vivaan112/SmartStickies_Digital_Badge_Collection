defmodule BadgeCollector.Certifiers.TotalSpentCertifier do
  @behaviour BadgeCollector.Certifier

  import Ecto.Query

  alias BadgeCollector.{Action, Badge, Certifier, Repo, User}

  @impl true
  def handles, do: "total_spent"

  @impl true
  def relavent_action?(%Action{type: "buy_item"} = action) do
    match?({:ok, _name, _cost}, Action.parse_purchase(action))
  end

  def relavent_action?(_action), do: false

  @impl true
  def try_certify(%Badge{id: badge_id, unlock_args: unlock_args}, %User{id: user_id}) do
    required = String.to_float(unlock_args || "0.0")
    spent = total_spent(user_id)

    if spent >= required do
      Certifier.issue(user_id, badge_id, "spent #{:erlang.float_to_binary(spent, decimals: 2)}")
    end
  end

  # unparseable payloads are skipped rather than failing the whole tally
  @spec total_spent(non_neg_integer()) :: float()
  defp total_spent(user_id) do
    from(a in Action, where: a.user_id == ^user_id and a.type == "buy_item")
    |> Repo.all
    |> Enum.reduce(0.0, fn action, sum ->
      case Action.parse_purchase(action) do
        {:ok, _name, cost} -> sum + cost
        :error -> sum
      end
    end)
  end
end
