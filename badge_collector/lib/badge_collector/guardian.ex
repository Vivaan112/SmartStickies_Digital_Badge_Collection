defmodule BadgeCollector.Guardian do
  use Guardian, otp_app: :badge_collector

  alias BadgeCollector.User

  def subject_for_token(user, _claims), do: {:ok, to_string(user.id)}

  def resource_from_claims(%{"sub" => id} = _claims) do
    case User.get_user(id) do
      nil -> {:error, :not_found}
      user -> {:ok, user}
    end
  end
end
