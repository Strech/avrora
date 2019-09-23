defmodule Avrora.Storage.Registry do
  @moduledoc """
  A small wrapper for [Confluent Schema Registry](https://docs.confluent.io/current/schema-registry/develop/api.html),
  with as less as possible functionality. Inspired by [Schemex](https://github.com/bencebalogh/schemex).
  """

  require Logger

  alias Avrora.{Config, Name, Schema}

  @behaviour Avrora.Storage
  @content_type "application/vnd.schemaregistry.v1+json"

  @doc """
  Fetch the latest version of the schema registered under a subject name.

  ## Examples

      iex> {:ok, schema} = Avrora.Storage.Registry.get("io.confluent.Payment")
      iex> schema.full_name
      "io.confluent.Payment"
  """
  def get(key) when is_binary(key) do
    with {:ok, schema_name} <- Name.parse(key),
         {name, version} <- {schema_name.name, schema_name.version || "latest"},
         {:ok, response} <- http_client_get("subjects/#{name}/versions/#{version}"),
         {:ok, id} <- Map.fetch(response, "id"),
         {:ok, version} <- Map.fetch(response, "version"),
         {:ok, schema} <- Map.fetch(response, "schema"),
         {:ok, schema} <- Schema.parse(schema) do
      Logger.debug("obtaining schema `#{schema_name.name}` with version `#{version}`")

      {:ok, %{schema | id: id, version: version}}
    end
  end

  @doc """
  Fetch a schema by a globally unique ID.

  ## Examples

      ...> {:ok, schema} = Avrora.Storage.Registry.get(1)
      ...> schema.full_name
      "io.confluent.Payment"
  """
  def get(key) when is_integer(key) do
    with {:ok, response} <- http_client_get("schemas/ids/#{key}"),
         {:ok, schema} <- Map.fetch(response, "schema"),
         {:ok, schema} <- Schema.parse(schema) do
      Logger.debug("obtaining schema with global id `#{key}`")

      {:ok, %{schema | id: key}}
    end
  end

  @doc """
  Register a new version of a schema under the subject name.

  ## Examples

      iex> schema = ~s({"fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}],"name":"Payment","namespace":"io.confluent","type":"record"})
      iex> {:ok, schema} = Avrora.Storage.Registry.put("io.confluent.examples.Payment", schema)
      iex> schema.full_name
      "io.confluent.Payment"
  """
  def put(key, value) when is_binary(key) and is_binary(value) do
    with {:ok, schema_name} <- Name.parse(key),
         {:ok, response} <- http_client_post("subjects/#{schema_name.name}/versions", value),
         {:ok, id} <- Map.fetch(response, "id"),
         {:ok, schema} <- Schema.parse(value) do
      unless is_nil(schema_name.version) do
        Logger.warn(
          "storing schema with version is not allowed, `#{schema_name.name}` used instead"
        )
      end

      Logger.debug("new schema `#{schema_name.name}` stored with global id `#{id}`")

      {:ok, %{schema | id: id}}
    end
  end

  @doc false
  def put(_key, _value), do: {:error, :unsupported}

  @doc false
  @spec configured?() :: true | false
  def configured?, do: !is_nil(Config.registry_url())

  defp http_client_get(path) do
    if configured?(),
      do: path |> to_url() |> http_client().get() |> handle(),
      else: {:error, :unconfigured_registry_url}
  end

  defp http_client_post(path, payload) do
    if configured?() do
      path |> to_url() |> http_client().post(payload, content_type: @content_type) |> handle()
    else
      {:error, :unconfigured_registry_url}
    end
  end

  defp to_url(path), do: "#{Config.registry_url()}/#{path}"

  defp handle({:error, payload} = _response) when is_map(payload) do
    reason =
      case Map.get(payload, "error_code") do
        40401 -> :unknown_subject
        40402 -> :unknown_version
        40403 -> :unknown_schema
        409 -> :conflict
        422 -> :unprocessable
        _ -> payload
      end

    {:error, reason}
  end

  defp handle(response), do: response

  defp http_client, do: Config.http_client()
end
