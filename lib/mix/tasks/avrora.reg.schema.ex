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

  alias Avrora.Config

  @shortdoc "Register schema(s) in the Confluent Schema Registry"

  @impl Mix.Task
  def run(argv) do
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
        register(name)

      _ ->
        message = """
        don't know how to handle `#{Enum.join(argv, " ")}'
        please use #{IO.ANSI.yellow()}mix help avrora.reg.schema#{IO.ANSI.reset()} for help
        """

        IO.puts(:stderr, message)
        exit({:shutdown, 1})
    end
  end

  defp register(schema_name) do
    IO.puts("Registering #{schema_name}")
  end

  defp schemas_path, do: Config.self().schemas_path()
end
