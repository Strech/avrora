defmodule Mix.Tasks.Avrora.Reg.Schema do
  use Mix.Task

  @moduledoc """
  Register either one schema or all schemas in the `Avrora.Config.schemas_path`
  directory (or your private client schemas path).

      mix avrora.reg.schema [--all] [--name NAME] [--as NEW_NAME] [--module MODULE]

  The search of the schemas will be performed under path configured in `schemas_path`
  configuration option. One of either option must be given.

  ## Command line options

    * `--name` - the full name of the schema to register (exclusive with `--all`)
    * `--as` - the name which will be used to register schema (i.e subject)
    * `--all` - register all found schemas
    * `--module` - the private Avrora client module (i.e MyClient)
    * `--appconfig` - the app config file name to load from `config/` folder (i.e runtime)

  The `--module` option allows to use your private Avrora client module instead of
  the default `Avrora`.

  The `--as` option is possible to use only together with `--name`.

  The `--name` option expects that given schema name will comply to
  `Avrora.Storage.File` module rules.

  The `--appconfig` option expects just application config file name without an extension
  and will load it additionally to default. Note: runtime config doesn't support imports!

  For example, if the schema name is `io.acme.Payment` it should be stored
  as `<schemas path>/io/acme/Payment.avsc`

  ## Usage

      mix avrora.reg.schema --name io.acme.Payment
      mix avrora.reg.schema --name io.acme.Payment --as MyCustomName
      mix avrora.reg.schema --all --appconfig runtime
      mix avrora.reg.schema --all --module MyClient
      mix avrora.reg.schema --all
  """
  @shortdoc "Register schema(s) in the Confluent Schema Registry"

  alias Mix.Tasks

  @cli_options [
    strict: [
      as: :string,
      all: :boolean,
      name: :string,
      module: :string,
      appconfig: :string
    ]
  ]

  @impl Mix.Task
  def run(argv) do
    Tasks.Loadpaths.run(["--no-elixir-version-check", "--no-archives-check"])

    {opts, _, _} = OptionParser.parse(argv, @cli_options)
    {module_name, opts} = Keyword.pop(opts, :module, "Avrora")
    {app_config, opts} = Keyword.pop(opts, :appconfig)

    module = Module.concat(Elixir, String.trim(module_name))
    config = Module.concat(module, Config)
    registrar = Module.concat(module, Utils.Registrar)

    {:ok, _} = Application.ensure_all_started(:avrora)
    {:ok, _} = module.start_link()

    unless is_nil(app_config) do
      Mix.Project.config()
      |> Keyword.get(:config_path)
      |> Path.dirname()
      |> Path.join("#{app_config}.exs")
      |> List.wrap()
      |> Tasks.Loadconfig.run()
    end

    case opts |> Keyword.keys() |> Enum.sort() do
      [:all] ->
        [config.self().schemas_path(), "**", "*.avsc"]
        |> Path.join()
        |> Path.wildcard()
        |> Enum.each(fn file_path ->
          file_path
          |> Path.relative_to(config.self().schemas_path())
          |> Path.rootname()
          |> String.replace("/", ".")
          |> register_schema_by_name(registrar)
        end)

      [:name] ->
        opts[:name] |> String.trim() |> register_schema_by_name(registrar)

      [:as, :name] ->
        opts[:name]
        |> String.trim()
        |> register_schema_by_name(registrar, as: String.trim(opts[:as]))

      _ ->
        message = """
        don't know how to handle `#{Enum.join(argv, " ")}'
        please use #{IO.ANSI.yellow()}mix help avrora.reg.schema#{IO.ANSI.reset()} for help
        """

        Mix.shell().error(message)
        exit({:shutdown, 1})
    end
  end

  defp register_schema_by_name(name, registrar, opts \\ []) do
    opts = Keyword.merge(opts, force: true)

    case registrar.register_schema_by_name(name, opts) do
      {:ok, _} ->
        case Keyword.get(opts, :as) do
          nil -> Mix.shell().info("schema `#{name}' will be registered")
          new_name -> Mix.shell().info("schema `#{name}' will be registered as `#{new_name}'")
        end

      {:error, error} ->
        Mix.shell().error("schema `#{name}' will be skipped due to an error `#{error}'")
    end
  end
end
