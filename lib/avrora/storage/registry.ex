defmodule Avrora.Storage.Registry do
  @moduledoc """
  `Avora.Storage` behavior implementation which uses [Confluent Schema
  Registry](https://docs.confluent.io/current/schema-registry/develop/api.html).

  This only implements the minimum client functionality needed to talk with the registry.
  Inspired by [Schemex](https://github.com/bencebalogh/schemex).
  """

  require Logger

  alias Avrora.{Config, Schema}
  alias Avrora.Schema.Name

  @behaviour Avrora.Storage
  @content_type "application/vnd.schemaregistry.v1+json"

  @doc """
  Get schema by subject name.

  Uses version if defined or latest.

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
         {:ok, references} <- extract_references(response),
         {:ok, schema} <- Schema.parse(schema, make_reference_lookup_function(references)) do
      Logger.debug("obtaining schema `#{schema_name.name}` with version `#{version}`")

      {:ok, %{schema | id: id, version: version}}
    end
  end

  @doc """
  Get schema by integer ID.

  ## Examples

      ...> {:ok, schema} = Avrora.Storage.Registry.get(1)
      ...> schema.full_name
      "io.confluent.Payment"
  """
  def get(key) when is_integer(key) do
    with {:ok, response} <- http_client_get("schemas/ids/#{key}"),
         {:ok, schema} <- Map.fetch(response, "schema"),
         {:ok, references} <- extract_references(response),
         {:ok, schema} <- Schema.parse(schema, make_reference_lookup_function(references)) do
      Logger.debug("obtaining schema with global id `#{key}`")

      {:ok, %{schema | id: key}}
    end
  end

  @doc """
  Register new version of schema under subject name.

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
  def configured?, do: !is_nil(registry_url())

  defp extract_references(response) do
    references =
      response
      |> Map.get("references", [])
      |> Enum.map(&"#{Map.get(&1, "subject")}:#{Map.get(&1, "version", "latest")}")
      |> Task.async_stream(__MODULE__, :get, [])
      |> Enum.reduce(%{}, fn result, memo ->
        case result do
          {:ok, {:ok, schema}} -> Map.put(memo, schema.full_name, schema.json)
          {:ok, {:error, error}} -> throw(error)
          {:exit, reason} -> throw(reason)
        end
      end)

    {:ok, references}
  catch
    :unknown_subject -> {:error, :unknown_reference_subject}
    error -> {:error, error}
  end

  def make_reference_lookup_function(map) when map_size(map) == 0,
    do: &Avrora.Schema.reference_lookup/1

  def make_reference_lookup_function(references),
    do: &Map.fetch(references, &1)

  defp http_client_get(path) do
    if configured?(),
      do: path |> to_url() |> http_client().get(headers()) |> handle(),
      else: {:error, :unconfigured_registry_url}
  end

  defp http_client_post(path, payload) do
    if configured?() do
      headers = headers() |> Keyword.put(:content_type, @content_type)
      path |> to_url() |> http_client().post(payload, headers) |> handle()
    else
      {:error, :unconfigured_registry_url}
    end
  end

  # NOTE: Maybe move to compile-time?
  defp headers do
    case registry_auth() do
      {:basic, [username, password]} ->
        credentials = :base64.encode("#{username}:#{password}")
        [authorization: "Basic #{credentials}"]

      nil ->
        []
    end
  end

  defp to_url(path), do: "#{registry_url()}/#{path}"

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

  defp http_client, do: Config.self().http_client()
  defp registry_url, do: Config.self().registry_url()
  defp registry_auth, do: Config.self().registry_auth()
end
