defmodule Gunbot do
  @moduledoc """
  Application entrypoint for `Gunbot`.
  """

  use Application

  def start(_type, _args) do
    children = [
      Gunbot.Consumer,
      Gunbot.Repo,
      Gunbot.Monitor
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: Gunbot.Supervisor)
  end
end
