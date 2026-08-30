defmodule BadgeCollector.Certifier do
  alias BadgeCollector.{Action, Badge, Certificate, User}

  @callback handles() :: String.t() # what :unlock_type is this for
  @callback relavent_action?(action :: Action.t()) :: boolean()
  @callback try_certify(badge :: Badge.t(), user :: User.t()) :: Certificate.t() | nil

  @certifiers [
    BadgeCollector.Certifiers.LoginStreakCertifier,
    BadgeCollector.Certifiers.PurchaseCountCertifier,
    BadgeCollector.Certifiers.TotalSpentCertifier,
    BadgeCollector.Certifiers.TagCountCertifier,
    BadgeCollector.Certifiers.TapCountCertifier,
    BadgeCollector.Certifiers.LocationCountCertifier,
    BadgeCollector.Certifiers.BadgeCountCertifier,
    BadgeCollector.Certifiers.CollectionCertifier
  ]

  @meta_types ~w(badge_count collection_complete)

  @spec registry() :: %{String.t() => module()}
  defp registry, do: Map.new(@certifiers, &{&1.handles(), &1})

  @doc "Group the user's uncertified badges by unlock_type, give each group to its certifier, and collect whatever certificates got issued"
  @spec run(Action.t(), User.t()) :: [Certificate.t()]
  def run(action, user) do
    registry = registry()

    user
    |> User.unearned_badges(true)
    |> Enum.group_by(& &1.unlock_type)
    |> Enum.sort_by(fn {unlock_type, _badges} -> unlock_type in @meta_types end)
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

  @doc "unlock_args is JSON. A malformed value is a seeding mistake, so it
  raises rather than silently never awarding the badge."
  @spec parse_args(Badge.t()) :: map()
  def parse_args(%Badge{unlock_args: nil}), do: %{}

  def parse_args(%Badge{unlock_args: unlock_args, name: name}) do
    case Jason.decode(unlock_args) do
      {:ok, args} when is_map(args) ->
        args

      _ ->
        raise ArgumentError,
              "badge #{inspect(name)} has unparseable unlock_args: #{inspect(unlock_args)}"
    end
  end

  @spec required_count(map(), Badge.t()) :: non_neg_integer()
  def required_count(args, %Badge{name: name}) do
    case Map.get(args, "count", 1) do
      count when is_integer(count) and count >= 0 ->
        count

      other ->
        raise ArgumentError,
              "badge #{inspect(name)} needs an integer count, got: #{inspect(other)}"
    end
  end

  @spec meta_types() :: [String.t()]
  def meta_types, do: @meta_types
end
