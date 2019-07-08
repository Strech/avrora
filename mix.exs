defmodule Avrora.MixProject do
  use Mix.Project

  def project do
    [
      app: :avrora,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger, :inets, :ssl]
    ]
  end

  # Pathes to compile
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.1"},
      {:avro_ex, git: "https://github.com/beam-community/avro_ex.git", sha: " 9a02fd6"},
      {:mox, "~> 0.5", only: :test},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:credo, "~> 1.0.0", only: :dev, runtime: false}
    ]
  end
end
