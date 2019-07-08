defmodule Avrora.RegistryStorage do
  @moduledoc """
  A small wrapper for [Confluent Schema Registry](https://docs.confluent.io/current/schema-registry/develop/api.html),
  with as less as possible functionality. Inspired by [Schemex](https://github.com/bencebalogh/schemex).
  """

  alias Avrora.Schema

  @behaviour Avrora.Storage

  @doc """
  Fetch the latest version of the schema registered under a subject name.

  ## Examples

      iex> {:ok, avro} = Avrora.RegistryStorage.get("io.confluent.Payment")
      iex> avro.schema.schema.qualified_names
      ["io.confluent.Payment"]
  """
  def get(key) when is_binary(key) do
    with {:ok, response} <- http_client().get("subjects/#{key}/versions/latest"),
         {:ok, version} <- Map.fetch(response, "version"),
         {:ok, schema} <- Map.fetch(response, "schema"),
         {:ok, schema} <- Schema.parse(schema) do
      {:ok, %{schema | version: version}}
    end
  end

  @doc """
  Fetch a schema by a globally unique ID.

  FIXME: Can't use a real docs with iex> because don't know how to make it work

  ## Examples

      {:ok, avro} = Avrora.RegistryStorage.get(1)
      avro.schema.schema.qualified_names
      ["io.confluent.examples.Payment"]
  """
  def get(key) when is_integer(key) do
    with {:ok, response} <- http_client().get("schemas/ids/#{key}"),
         {:ok, schema} <- Map.fetch(response, "schema"),
         {:ok, schema} <- Schema.parse(schema) do
      {:ok, %{schema | id: key}}
    end
  end

  @doc """
  Register a new version of a schema under the subject name.

  ## Examples

      iex> schema = %{"namespace" => "io.confluent", "type" => "record", "name" => "Payment", "fields" => [%{"name" => "id", "type" => "string"}, %{"name" => "amount", "type" => "double"}]}
      iex> {:ok, avro} = Avrora.RegistryStorage.put("io.confluent.examples.Payment", schema)
      iex> avro.schema.schema.qualified_names
      ["io.confluent.Payment"]
  """
  def put(key, value) when is_binary(key) and (is_map(value) or is_binary(value)) do
    with {:ok, response} <- http_client().post("subjects/#{key}/versions", value),
         {:ok, id} <- Map.fetch(response, "id"),
         {:ok, schema} <- Schema.parse(value) do
      {:ok, %{schema | id: id}}
    end
  end

  @doc false
  def put(_key, _value), do: {:error, :unsupported}

  defp http_client, do: Application.get_env(:avrora, :http_client)
end
