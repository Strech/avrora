defmodule Avrora.SchemaLoader do
  @moduledoc """
  Reads and parse schema from the disk with conventional name resoltion.

  For instance schema name `<namespace>.<namespace>.<name>` will be converted to
  `namespace/namespace/name.avsc` path.
  """

  @extension ".avsc"

  @doc """
  Load the schema from the disk by it's full name.

  Given name should contain a namespace and the schemas should be placed with a
  convention – namespace segment is a folder name, hence a schema with a
  full name: `org.amazing.hello` should be placed like this

  .
  ├── lib/
  ├── priv/
  │   ├── ...
  │   └── schemas/
  │       └── org/
  │           └── amazing/
  │               └── hello.avsc
  └── ...

  ## Examples

      iex> Avrora.SchemaLoader.load("io.confluent.examples.Payment")
      {
        :ok,
        %{
          "name" => "Payment",
          "namespace" => "io.confluent.examples",
          "type" => "record",
          "fields" => [
            %{"name" => "id", "type" => "string"},
            %{"name" => "amount", "type" => "double"}
          ]
        }
      }
  """
  @spec load(String.t()) :: {:ok, map()} | {:error, any()}
  def load(name) do
    case Path.join(schemas_path(), name_to_filename(name)) |> File.read() do
      {:ok, body} -> Jason.decode(body)
      {:error, reason} -> {:error, reason}
    end
  end

  defp name_to_filename(name), do: String.replace(name, ".", "/") <> @extension
  defp schemas_path, do: Application.get_env(:avrora, :schemas_path)
end
