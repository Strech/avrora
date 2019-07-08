defmodule Avrora.FileStorage do
  @moduledoc """
  Reads and parse schema from the disk with conventional name resoltion.

  For instance schema name `<namespace>.<namespace>.<name>` will be converted to
  `namespace/namespace/name.avsc` path.
  """

  @behaviour Avrora.Storage
  @extension ".avsc"

  @doc """
  Reads the schema from the disk by it's full name.

  Given name should contain a namespace and the schemas should be placed by a
  convention – namespace segment is a folder name, hence a schema with a
  full name: `io.confluent.Payment` should be placed like this

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

      iex> {:ok, avro} = Avrora.FileStorage.get("io.confluent.examples.Payment")
      iex> avro.schema.qualified_names
      ["io.confluent.examples.Payment"]
  """
  def get(key) when is_binary(key) do
    with {:ok, body} <- Path.join(schemas_path(), name_to_filename(key)) |> File.read() do
      AvroEx.Schema.parse(body)
    end
  end

  @doc false
  def get(key) when is_integer(key), do: {:error, :unsupported}
  @doc false
  def put(_key, _value), do: {:error, :unsupported}

  defp name_to_filename(name), do: String.replace(name, ".", "/") <> @extension
  defp schemas_path, do: Application.get_env(:avrora, :schemas_path)
end
