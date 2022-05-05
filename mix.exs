defmodule Gunbot.MixProject do
  use Mix.Project

  def project do
    [
      app: :gunbot,
      version: "1.0.0",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Gunbot, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nostrum, git: "https://github.com/Kraigie/nostrum.git"},
      {:httpoison, "~> 1.7"},
      {:jason, "~> 1.2"},
      {:ecto_sql, "~> 3.4"},
      {:postgrex, "~> 0.15"}
    ]
  end
end
