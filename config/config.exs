use Mix.Config

config :avrora,
  schemas_path: Path.expand("./test/fixtures/schemas"),
  registry_url: nil,
  registry_auth: nil,
  names_cache_ttl: :infinity

config :logger, :console, format: "$time $metadata[$level] $levelpad$message\n"
