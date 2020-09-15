defmodule Gunbot.Consumer do

  require Logger
  use Nostrum.Consumer
  alias Gunbot.Commands

  def start_link, do: Consumer.start_link(__MODULE__)

  def handle_event({:MESSAGE_CREATE, msg, _ws_state}) do
    unless msg.author.bot do
      Logger.debug(inspect(msg, pretty: true))
      if matches = Regex.run(~r/^#{Commands.command_prefix}\s*([\w-]+)/, msg.content) do
        matches
        |> Enum.at(1)
        |> String.downcase()
        |> Commands.dispatch(msg)
      end
    end
  end

  def handle_event(_event) do
    :noop
  end

end
