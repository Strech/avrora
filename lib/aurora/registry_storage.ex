defmodule Avrora.RegistryStorage do
  @moduledoc """
  A small wrapper for [Confluent Schema Registry](https://docs.confluent.io/current/schema-registry/develop/api.html),
  with as less as possible functionality. Inspired by [Schemex](https://github.com/bencebalogh/schemex).
  """

  @behaviour Avrora.Storage

  @doc """
  Fetch the latest version of the schema registered under a subject name.

  ## Examples

      iex> {:ok, avro} = Avrora.RegistryStorage.get("io.confluent.examples.Payment")
      iex> avro.schema.qualified_names
      ["io.confluent.examples.Payment"]
  """
  def get(key) when is_binary(key) do
    with {:ok, response} <- http_client().get("subjects/#{key}/versions/latest") do
      Map.get(response, "schema") |> AvroEx.Schema.parse()
    end
  end

  @doc """
  Fetch a schema by a globally unique ID.

  ## Examples

      iex> {:ok, avro} = Avrora.RegistryStorage.get(1)
      iex> avro.schema.qualified_names
      ["io.confluent.examples.Payment"]
  """
  def get(key) when is_integer(key) do
    with {:ok, response} <- http_client().get("schemas/ids/#{key}") do
      Map.get(response, "schema") |> AvroEx.Schema.parse()
    end
  end

  @doc """
  Register a new version of a schema under the subject name.

  ## Examples

      iex> Avrora.RegistryStorage.put("io.confluent.examples.Payment", %{"type" => "string"})
      {:ok, %{"type" => "string"}}
  """
  def put(key, value) when is_binary(key) and is_map(value) do
    http_client().post("subjects/#{key}/versions", value)
  end

  @doc false
  def put(_key, _value), do: {:error, :unsupported}

  defp http_client, do: Application.get_env(:avrora, :http_client)
end
