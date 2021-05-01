defmodule GunbotTest do
  use ExUnit.Case
  doctest Gunbot

  alias Gunbot.TrackedSearch

  test "Invalid tracked search" do
    ts_cs =
      TrackedSearch.changeset(%TrackedSearch{}, %{
        user_id: -333,
        guild_id: -444,
        channel_id: -555,
        user_nickname: "test",
        keywords: "",
        max_price: :invalid
      })

    assert ts_cs.valid? == false
  end

  test "Valid tracked search" do
    ts_cs =
      TrackedSearch.changeset(%TrackedSearch{}, %{
        user_id: 1_111_111_111,
        guild_id: 2_222_222_222,
        channel_id: 3_333_333_333,
        user_nickname: "test",
        keywords: "hello",
        max_price: 300,
        last_checked: DateTime.utc_now()
      })

    assert ts_cs.valid? == true
  end
end
