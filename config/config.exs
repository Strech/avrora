use Mix.Config

config :avrora,
  schemas_path: Path.expand("./test/fixtures/schemas"),
  registry_url: nil,
  names_cache_ttl: :timer.minutes(5)

config :logger, :console, format: "$time $metadata[$level] $levelpad$message\n"
