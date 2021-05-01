import Config

config :gunbot, Gunbot.Repo,
  database: System.get_env("DATABASE_NAME", "gunbot"),
  username: System.get_env("DATABASE_USER", "postgres"),
  password: System.get_env("DATABASE_PASS", "postgres"),
  hostname: System.get_env("DATABASE_HOST", "localhost"),
  ssl: System.get_env("DATABASE_SSL", "true") == "true"

config :nostrum,
  token: System.get_env("DISCORD_API_KEY"),
  num_shards: 1

config :gunbot,
  dev_key: System.get_env("GUNBROKER_API_KEY"),
  api_url: System.get_env("GUNBROKER_API_URL", "https://api.gunbroker.com/v1"),
  gui_url: System.get_env("GUNBROKER_GUI_URL", "https://www.gunbroker.com/"),
  ecto_repos: [Gunbot.Repo]
