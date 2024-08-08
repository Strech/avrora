import Config

config :avrora,
  schemas_path: Path.expand("./test/fixtures/schemas"),
  registry_url: nil,
  registry_auth: nil,
  registry_user_agent: nil,
  registry_schemas_autoreg: true,
  convert_null_values: true,
  names_cache_ttl: :infinity

config :logger, :console, format: "$time $metadata[$level] $message\n"
