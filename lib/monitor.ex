defmodule Gunbot.Monitor do
  use GenServer

  @loop_period 1000 * 60 * 5 # 5 minutes

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
    content = Gunbot.Repo.all(Gunbot.TrackedSearch)
    |> Enum.reduce("", fn ts, acc ->
      search_message = Gunbot.Commands.do_scheduled_search(ts)
      if search_message, do: acc <> "#{search_message}\n", else: acc
    end)
    unless content == "" do
      Nostrum.Api.create_message(Application.get_env(:gunbot, :default_channel_id), content)
    end
  end

end
