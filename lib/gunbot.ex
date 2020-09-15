defmodule Gunbot do
  @moduledoc """
  Application entrypoint for `Gunbot`.
  """

  use Application
  use Supervisor

  def start(_type, _args) do
    start_link([])
  end

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  def init(:ok) do
    children = [
      Gunbot.Consumer,
      Gunbot.Repo,
      Gunbot.Monitor
    ]
    Supervisor.init(children, strategy: :one_for_one)
  end

end
