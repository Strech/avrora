defmodule Avrora.MixProject do
  use Mix.Project

  def project do
    [
      app: :avrora,
      version: "0.1.0",
      elixir: "~> 1.6",
      description: description(),
      package: package(),
      docs: docs(),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"}
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      deps: deps()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl]
    ]
  end

  # Pathes to compile
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    """
    Avrora is an Elixir library for convenient work with AVRO messages and schemas.
    It is highly inspired by AvroTurf Ruby gem and has just a few dependencies.
    """
  end

  defp package do
    [
      maintainers: ["Sergey Fedorov"],
      licenses: ["MIT"],
      links: %{GitHub: "https://github.com/Strech/avrora"}
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "misc/logo.png",
      extras: [
        "README.md"
      ]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.1"},
      {:avro_ex, git: "https://github.com/beam-community/avro_ex.git", sha: " 9a02fd6"},
      {:mox, "~> 0.5", only: :test},
      {:ex_doc, "~> 0.13", only: :dev},
      {:dialyxir, "~> 1.0.0-rc.6", only: :dev, runtime: false},
      {:credo, "~> 1.0.0", only: :dev, runtime: false},
      {:excoveralls, "~> 0.11", only: :test}
    ]
  end
end
