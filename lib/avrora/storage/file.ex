defmodule Avrora.Storage.File do
  @moduledoc """
  `Avora.Storage` behavior implementation which uses the filesystem.

  Schema name `<namespace>.<namespace>.<name>` will be stored to path
  `namespace/namespace/name.avsc`.
  """

  require Logger
  alias Avrora.Config
  alias Avrora.Schema.Encoder, as: SchemaEncoder
  alias Avrora.Schema.Name

  @behaviour Avrora.Storage
  @extension ".avsc"

  @doc """
  Read schema from disk by full name, including namespace.

  Files are stored with each namespace component as a folder name.
  For example `io.acme.Payment` should be stored as follows:

      .
      ├── lib/
      ├── priv/
      │   ├── ...
      │   └── schemas/
      │       └── io/
      │           └── acme/
      │               └── Payment.avsc
      └── ...

  ## Examples

      iex> {:ok, schema} = Avrora.Storage.File.get("io.acme.Payment")
      iex> schema.full_name
      "io.acme.Payment"
  """
  @impl true
  def get(key) when is_binary(key) do
    with {:ok, schema_name} <- Name.parse(key),
         {:ok, body} <- read_schema_file_by_name(key) do
      SchemaEncoder.from_json(body, name: schema_name.name, reference_lookup_fun: &read_schema_file_by_name/1)
    end
  end

  @impl true
  def get(key) when is_integer(key), do: {:error, :unsupported}

  @impl true
  def put(_key, _value), do: {:error, :unsupported}

  # TODO: Move `Name.parse` outside of the method
  defp read_schema_file_by_name(name) do
    with {:ok, schema_name} <- Name.parse(name),
         filepath <- name_to_filepath(schema_name.name) do
      unless is_nil(schema_name.version) do
        Logger.warning("reading schema file with version is not allowed, `#{schema_name.name}` used instead")
      end

      Logger.debug("reading schema `#{schema_name.name}` from the file #{filepath}")
      File.read(filepath)
    end
  end

  defp name_to_filepath(name) do
    filename = String.replace(name, ".", "/") <> @extension
    Path.join(schemas_path(), filename)
  end

  defp schemas_path, do: Config.self().schemas_path()
end
