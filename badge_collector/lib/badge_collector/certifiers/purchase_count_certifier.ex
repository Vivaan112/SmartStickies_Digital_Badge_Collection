defmodule BadgeCollector.Certifiers.PurchaseCountCertifier do
  @behaviour BadgeCollector.Certifier

  import Ecto.Query

  alias BadgeCollector.{Action, Badge, Certifier, Repo, User}

  @impl true
  def handles, do: "purchase_count"

  @impl true
  def relavent_action?(%Action{type: "buy_item"}), do: true
  def relavent_action?(_action), do: false

  @impl true
  def try_certify(%Badge{id: badge_id, unlock_args: unlock_args}, %User{id: user_id}) do
    required = String.to_integer(unlock_args || "1")
    count = purchase_count(user_id)

    if count >= required do
      Certifier.issue(user_id, badge_id, "#{count} purchases")
    end
  end

  @spec purchase_count(non_neg_integer()) :: non_neg_integer()
  defp purchase_count(user_id) do
    from(a in Action, where: a.user_id == ^user_id and a.type == "buy_item")
    |> Repo.aggregate(:count)
  end
end
