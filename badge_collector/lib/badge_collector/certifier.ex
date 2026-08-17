defmodule BadgeCollector.Certifier do
  alias BadgeCollector.{Action, Badge, Certificate, User}

  @callback handles() :: String.t() # what :unlock_type is this for
  @callback relavent_action?(action :: Action.t()) :: boolean()
  @callback try_certify(badge :: Badge.t(), user :: User.t()) :: Certificate.t() | nil

  @certifiers [
    BadgeCollector.Certifiers.LoginStreakCertifier,
    BadgeCollector.Certifiers.PurchaseCountCertifier,
    BadgeCollector.Certifiers.TotalSpentCertifier
  ]

  @spec registry() :: %{String.t() => module()}
  defp registry, do: Map.new(@certifiers, &{&1.handles(), &1})

  @doc "Group the user's uncertified badges by unlock_type, give each group to its certifier, and collect whatever certificates got issued"
  @spec run(Action.t(), User.t()) :: [Certificate.t()]
  def run(action, user) do
    registry = registry()

    user
    |> User.unearned_badges(true)
    |> Enum.group_by(& &1.unlock_type)
    |> Enum.flat_map(fn {unlock_type, badges} ->
      with {:ok, certifier} <- Map.fetch(registry, unlock_type),
           true <- certifier.relavent_action?(action)
      do
        Enum.map(badges, &certifier.try_certify(&1, user))
      else
        _ -> []
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  @spec issue(non_neg_integer(), non_neg_integer(), String.t()) :: Certificate.t() | nil
  def issue(user_id, badge_id, info) do
    case Certificate.new(user_id, badge_id, info) do
      {:ok, certificate} -> certificate
      {:error, _errors} -> nil
    end
  end
end
