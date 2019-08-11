use Mix.Config

config :avrora,
  schemas_path: Path.expand("./test/fixtures/schemas"),
  registry_url: nil

config :logger, :console, format: "$time $metadata[$level] $levelpad$message\n"
