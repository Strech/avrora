use Mix.Config

config :avrora,
  schemas_path: Path.expand("./priv/schemas"),
  registry_url: nil

config :logger, :console, format: "$time $metadata[$level] $levelpad(Avrora) $message\n"
