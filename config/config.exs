use Mix.Config

config :avrora,
  schemas_path: Path.expand("./test/fixtures/schemas"),
  registry_url: nil,
  registry_auth: nil,
  registry_schemas_autoreg: true,
  convert_null_values: true,
  names_cache_ttl: :infinity,
  user_agent_header: nil

config :logger, :console, format: "$time $metadata[$level] $levelpad$message\n"
