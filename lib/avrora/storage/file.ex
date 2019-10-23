defmodule Avrora.Storage.File do
  @moduledoc """
  `Avora.Storage` behavior implementation which uses the filesystem.

  Schema name `<namespace>.<namespace>.<name>` will be stored to path
  `namespace/namespace/name.avsc`.
  """

  require Logger
  alias Avrora.{Config, Name, Schema}

  @behaviour Avrora.Storage
  @extension ".avsc"

  @doc """
  Read schema from disk by full name, including namespace.

  Files are stored with each namespace component as a folder name.
  For example `io.confluent.Payment` should be stored as follows:

  .
  ├── lib/
  ├── priv/
  │   ├── ...
  │   └── schemas/
  │       └── io/
  │           └── confluent/
  │               └── Payment.avsc
  └── ...

  ## Examples

      iex> {:ok, schema} = Avrora.Storage.File.get("io.confluent.examples.Payment")
      iex> schema.full_name
      "io.confluent.Payment"
  """
  def get(key) when is_binary(key) do
    with {:ok, schema_name} <- Name.parse(key),
         filepath <- Path.join(schemas_path(), name_to_filename(schema_name.name)),
         {:ok, body} <- File.read(filepath) do
      unless is_nil(schema_name.version) do
        Logger.warn(
          "file reading schema with version is not allowed, `#{schema_name.name}` used instead"
        )
      end

      Logger.debug("reading schema `#{schema_name.name}` from the file #{filepath}")

      Schema.parse(body)
    end
  end

  @doc false
  def get(key) when is_integer(key), do: {:error, :unsupported}

  @doc false
  def put(_key, _value), do: {:error, :unsupported}

  defp name_to_filename(name), do: String.replace(name, ".", "/") <> @extension
  defp schemas_path, do: Config.schemas_path()
end
