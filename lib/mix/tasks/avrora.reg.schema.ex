defmodule Mix.Tasks.Avrora.Reg.Schema do
  use Mix.Task

  @moduledoc """
  Register either one schema or all schemas in the `Avrora.Config.schemas_path`
  directory.

      mix avrora.reg.schema [--all] [--name NAME]

  The search of the schemas will be performed under path configured in `schemas_path`
  configuration option. One of either option must be given.

  ## Options

    * `--name` - the full name of the schema to register (exclusive with `--all`)
    * `--all` - register all found schemas

  The `--name` option expects that given schema name will comply to
  `Avrora.Storage.File` module rules.

  For example, if the schema name is `io.confluent.Payment` it should be stored
  as `<schemas path>/io/confluent/Payment.avsc`

  ## Usage

      mix avrora.reg.schema --name io.confluent.Payment
      mix avrora.reg.schema --all
  """

  require Logger
  alias Avrora.Config
  alias Avrora.Schema.Name

  @shortdoc "Register schema(s) in the Confluent Schema Registry"

  @impl Mix.Task
  def run(argv) do
    {:ok, _} = Application.ensure_all_started(:avrora)
    {:ok, _} = Avrora.start_link()

    case argv do
      ["--all"] ->
        [schemas_path(), "**", "*.avsc"]
        |> Path.join()
        |> Path.wildcard()
        |> Enum.each(fn file_path ->
          file_path
          |> Path.relative_to(schemas_path())
          |> Path.rootname()
          |> String.replace("/", ".")
          |> register()
        end)

      ["--name", name] ->
        name |> String.trim() |> register()

      _ ->
        message = """
        don't know how to handle `#{Enum.join(argv, " ")}'
        please use #{IO.ANSI.yellow()}mix help avrora.reg.schema#{IO.ANSI.reset()} for help
        """

        IO.puts(:stderr, message)
        exit({:shutdown, 1})
    end
  end

  defp register(name) do
    with {:ok, schema_name} <- Name.parse(name),
         {:ok, schema} <- file_storage().get(name) do
      Logger.info("schema `#{schema_name.name}` will be registered")
      registry_storage().put(schema_name.name, schema.json)
    else
      {:error, error} ->
        Logger.warn("schema #{name} will be skipped due to an error `#{error}'")
    end
  end

  defp schemas_path, do: Config.self().schemas_path()
  defp file_storage, do: Config.self().file_storage()
  defp registry_storage, do: Config.self().registry_storage()
end
