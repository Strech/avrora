defmodule Integration.MixProject do
  use Mix.Project

  def project do
    [
      app: :integration,
      version: "0.1.0",
      elixir: "~> 1.6",
      start_permanent: Mix.env() == :prod,
      dialyzer: [
        plt_file: {:no_warn, "priv/plts/dialyzer.plt"},
        plt_add_apps: [:mix]
      ],
      deps: deps()
    ]
  end

  def application, do: []

  defp deps do
    [
      {:avrora, path: "../"},
      {:dialyxir, "~> 1.0.0", runtime: false}
    ]
  end
end
