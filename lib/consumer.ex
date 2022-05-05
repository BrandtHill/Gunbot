defmodule Gunbot.Consumer do
  require Logger
  use Nostrum.Consumer
  alias Gunbot.Commands
  alias Nostrum.Api

  def start_link, do: Consumer.start_link(__MODULE__)

  def handle_event({:READY, _event, _ws_state}) do
    {:ok, commands} = Api.get_global_application_commands()
    registered_commands = Enum.map(commands, fn x -> x.name end)
    all_commands = Commands.commands() |> Map.keys()

    (all_commands -- registered_commands)
    |> Enum.each(fn name ->
      {_, description, options} = Commands.commands()[name]

      Logger.debug("Creating global command: #{name}")

      Api.create_global_application_command(%{
        name: name,
        description: description,
        options: options
      })
    end)
  end

  def handle_event({:INTERACTION_CREATE, interaction, _ws_state}) do
    interaction
    |> Commands.dispatch()
    |> then(&Api.create_interaction_response(interaction, %{type: 4, data: %{content: &1}}))
  end

  def handle_event(_event) do
    :noop
  end
end
