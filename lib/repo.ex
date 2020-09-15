defmodule Gunbot.Repo do
  use Ecto.Repo,
    otp_app: :gunbot,
    adapter: Ecto.Adapters.Postgres
end
