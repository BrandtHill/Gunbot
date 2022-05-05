defmodule Gunbot.TrackedSearch do
  use Ecto.Schema
  import Nostrum.Snowflake, only: [is_snowflake: 1]

  import Ecto.Changeset

  @req_fields [
    :user_id,
    :guild_id,
    :channel_id,
    :user_nickname,
    :max_price,
    :keywords,
    :last_checked
  ]

  @allowed_fields [:category] ++ @req_fields

  schema "tracked_searches" do
    field(:user_id, :integer)
    field(:guild_id, :integer)
    field(:channel_id, :integer)
    field(:user_nickname, :string)
    field(:max_price, :integer)
    field(:keywords, :string)
    field(:category, :string, default: "Guns")
    field(:last_checked, :utc_datetime)
  end

  def changeset(tracked_search, params \\ %{}) do
    tracked_search
    |> cast(params, @allowed_fields)
    |> validate_required(@req_fields)
    |> validate_change(:user_id, &validate_snowflake/2)
    |> validate_change(:guild_id, &validate_snowflake/2)
    |> validate_change(:channel_id, &validate_snowflake/2)
  end

  def build(params) do
    changeset(%__MODULE__{}, params)
  end

  defp validate_snowflake(atom, value),
    do: (is_snowflake(value) && []) || [{atom, "must be a snowflake"}]
end
