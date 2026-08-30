defmodule BadgeCollector.Tap do
  @moduledoc """
  A decoded NFC tap payload. Actions of type "tap" carry this as JSON in
  their `data` column.
  """

  import Ecto.Query

  alias BadgeCollector.Repo
  alias BadgeCollector.Action

  @type t :: %__MODULE__{}

  @enforce_keys [:product_id]
  defstruct [:product_id, :name, :location_id, :context, tags: []]

  @spec parse(Action.t()) :: {:ok, t()} | :error
  def parse(%Action{type: "tap", data: data}), do: parse_data(data)
  def parse(_action), do: :error

  @spec parse_data(binary() | nil) :: {:ok, t()} | :error
  def parse_data(data) when is_binary(data) do
    with {:ok, %{"product_id" => product_id, "tags" => tags} = payload}
           when is_binary(product_id) and is_list(tags) <- Jason.decode(data) do
      {:ok,
       %__MODULE__{
         product_id: product_id,
         name: Map.get(payload, "name"),
         tags: Enum.filter(tags, &is_binary/1),
         location_id: Map.get(payload, "location_id"),
         context: Map.get(payload, "context")
       }}
    else
      _ -> :error
    end
  end

  def parse_data(_data), do: :error

  @doc "Every tap this user has made that we can actually read. Unparseable
  payloads are dropped rather than failing the whole lookup."
  @spec for_user(non_neg_integer()) :: [t()]
  def for_user(user_id) do
    from(a in Action,
      where: a.user_id == ^user_id and a.type == "tap",
      select: a.data
    )
    |> Repo.all
    |> Enum.map(&parse_data/1)
    |> Enum.flat_map(fn
      {:ok, tap} -> [tap]
      :error -> []
    end)
  end

  @spec tagged?(t(), String.t() | nil) :: boolean()
  def tagged?(_tap, nil), do: true
  def tagged?(%__MODULE__{tags: tags}, tag), do: tag in tags

  @spec in_context?(t(), String.t() | nil) :: boolean()
  def in_context?(_tap, nil), do: true
  def in_context?(%__MODULE__{context: context}, wanted), do: context == wanted
end
