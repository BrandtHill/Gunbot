defmodule Gunbot.Monitor do
  use GenServer
  alias Gunbot.{Commands, Repo, TrackedSearch}

  import Ecto.Query, only: [from: 2]

  @loop_period 1000 * 60 * 5 # 5 minutes

  @num_sec_day 60 * 60 * 24

  def start_link(_opts) do
    GenServer.start_link(__MODULE__, [])
  end

  def init(state) do
    loop()
    {:ok, state}
  end

  def handle_info(:loop, state) do
    loop()
    {:noreply, state}
  end

  def loop() do
    Task.start(fn -> do_check() end)
    Process.send_after(self(), :loop, @loop_period)
  end

  def do_check() do
    results = Repo.all(from t in TrackedSearch, where: t.last_checked < ^DateTime.add(DateTime.utc_now(), -@num_sec_day))

    searches = Enum.reduce(results, %{}, fn ts, acc ->
      list = acc |> Map.get(ts.channel_id, [])
      list = list ++ [ts]
      acc |> Map.put(ts.channel_id, list)
    end)

    Enum.each(Map.keys(searches), fn ch -> send_channel_message(ch, searches[ch]) end)
  end

  def send_channel_message(channel_id, search_list) do
    content =
      Enum.reduce(search_list, "", fn ts, acc ->
        TrackedSearch.changeset(ts, %{last_checked: DateTime.truncate(DateTime.utc_now, :second)}) |> Repo.update!
        search_message = Commands.do_scheduled_search(ts)
        if search_message, do: acc <> "#{search_message}\n", else: acc
      end)

    unless content == "", do: Nostrum.Api.create_message(channel_id, content)
  end

end
