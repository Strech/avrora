defmodule Mix.Tasks.Avrora.Reg.Schema do
  use Mix.Task

  @moduledoc """
  Register either one schema or all schemas in the `Avrora.Config.schemas_path`
  directory.

      mix avrora.reg.schema [--all] [--name NAME] [--as NEW_NAME]

  The search of the schemas will be performed under path configured in `schemas_path`
  configuration option. One of either option must be given.

  ## Options

    * `--name` - the full name of the schema to register (exclusive with `--all`)
    * `--as` - the name which will be used to register schema (i.e subject)
    * `--all` - register all found schemas

  The `--as` option is possible to use only together with `--name`.

  The `--name` option expects that given schema name will comply to
  `Avrora.Storage.File` module rules.

  For example, if the schema name is `io.confluent.Payment` it should be stored
  as `<schemas path>/io/confluent/Payment.avsc`

  ## Usage

      mix avrora.reg.schema --name io.confluent.Payment
      mix avrora.reg.schema --name io.confluent.Payment --as MySchemaName
      mix avrora.reg.schema --all
  """

  alias Avrora.{Config, Utils}

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

      ["--name", name, "--as", new_name] ->
        name |> String.trim() |> register(as: String.trim(new_name))

      _ ->
        message = """
        don't know how to handle `#{Enum.join(argv, " ")}'
        please use #{IO.ANSI.yellow()}mix help avrora.reg.schema#{IO.ANSI.reset()} for help
        """

        Mix.shell().error(message)
        exit({:shutdown, 1})
    end
  end

  defp register(name, opts \\ []) do
    opts = Keyword.merge(opts, force: true)

    case Utils.Registrar.register_schema_by_name(name, opts) do
      {:ok, _} ->
        message =
          if Keyword.has_key?(opts, :as) do
            "schema `#{name}' will be registered as `#{opts[:as]}'"
          else
            "schema `#{name}' will be registered"
          end

        Mix.shell().info(message)

      {:error, error} ->
        Mix.shell().error("schema `#{name}' will be skipped due to an error `#{error}'")
    end
  end

  defp schemas_path, do: Config.self().schemas_path()
end
