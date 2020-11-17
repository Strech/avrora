defmodule Avrora.MixProject do
  use Mix.Project

  def project do
    [
      app: :avrora,
      version: "0.13.0",
      elixir: "~> 1.6",
      description: description(),
      package: package(),
      docs: docs(),
      start_permanent: Mix.env() == :prod,
      test_coverage: [tool: ExCoveralls],
      elixirc_paths: elixirc_paths(Mix.env()),
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
      ],
      preferred_cli_env: [
        coveralls: :test,
        "coveralls.detail": :test,
        "coveralls.post": :test,
        "coveralls.html": :test
      ],
      deps: deps(),
      aliases: aliases()
    ]
  end

  def application do
    [
      extra_applications: [:logger, :inets, :ssl, :erlavro]
    ]
  end

  # Pathes to compile
  defp elixirc_paths(:test), do: ["test/support", "lib"]
  defp elixirc_paths(_), do: ["lib"]

  defp description do
    """
    An Elixir library for working with Avro messages conveniently.
    It supports local schema files and Confluent® schema registry.
    """
  end

  defp package do
    [
      maintainers: ["Sergey Fedorov"],
      licenses: ["MIT"],
      links: %{
        GitHub: "https://github.com/Strech/avrora"
      },
      files: [
        "lib",
        "assets",
        "mix.exs",
        "README.md",
        "LICENSE.md"
      ]
    ]
  end

  defp docs do
    [
      main: "readme",
      logo: "assets/logo.png",
      source_url: "https://github.com/Strech/avrora",
      before_closing_body_tag: fn _format ->
        """
        <script type="text/javascript">
          var image = document.getElementById("avroraLogo");
          image.src = image.getAttribute("src").replace("/assets", "assets");

          var nodoc = document.getElementsByClassName("nodoc");
          while (nodoc.length > 0) {
            nodoc[0].parentNode.removeChild(nodoc[0]);
          }
        </script>
        """
      end,
      extras: [
        "README.md"
      ]
    ]
  end

  defp deps do
    [
      {:jason, "~> 1.0"},
      {:erlavro, "~> 2.9.0"},
      {:credo, "~> 1.4.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.23", only: :dev, runtime: false},
      {:dialyxir, "~> 1.0.0", only: [:dev, :test], runtime: false},
      {:mox, "~> 1.0.0", only: :test},
      {:excoveralls, "~> 0.13", only: :test}
    ]
  end

  defp aliases do
    [
      docso: ["docs", "cmd open doc/index.html"],
      check: ["cmd mix coveralls", "dialyzer", "credo"],
      release: [
        "check",
        fn _ ->
          version = Keyword.get(project(), :version)
          Mix.shell().cmd("git tag v#{version}")
          Mix.shell().cmd("git push --tags")
        end,
        "hex.publish"
      ]
    ]
  end
end
