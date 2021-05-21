defmodule Gunbot.TrackedSearch do
  use Ecto.Schema
  import Nostrum.Snowflake, only: [is_snowflake: 1]

  @req_fields [
    :user_id,
    :guild_id,
    :channel_id,
    :user_nickname,
    :max_price,
    :keywords,
    :last_checked
  ]

  schema "tracked_searches" do
    field :user_id, :integer
    field :guild_id, :integer
    field :channel_id, :integer
    field :user_nickname, :string
    field :max_price, :integer
    field :keywords, :string
    field :category, :string, default: "Guns"
    field :last_checked, :utc_datetime
  end

  def changeset(tracked_search, params \\ %{}) do
    tracked_search
    |> Ecto.Changeset.cast(params, @req_fields)
    |> Ecto.Changeset.validate_required(@req_fields)
    |> Ecto.Changeset.validate_change(:user_id, fn :user_id, x ->
      if is_snowflake(x), do: [], else: [user_id: "must be a snowflake"]
    end)
    |> Ecto.Changeset.validate_change(:guild_id, fn :guild_id, x ->
      if is_snowflake(x), do: [], else: [guild_id: "must be a snowflake"]
    end)
    |> Ecto.Changeset.validate_change(:channel_id, fn :channel_id, x ->
      if is_snowflake(x), do: [], else: [channel_id: "must be a snowflake"]
    end)
  end
end
