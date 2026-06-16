defmodule Avrora.Storage.Registry do
  @moduledoc """
  `Avora.Storage` behavior implementation which uses [Confluent Schema
  Registry](https://docs.confluent.io/current/schema-registry/develop/api.html).

  This only implements the minimum client functionality needed to talk with the registry.
  Inspired by [Schemex](https://github.com/bencebalogh/schemex).
  """

  require Logger

  alias Avrora.Config
  alias Avrora.Schema.Encoder, as: SchemaEncoder
  alias Avrora.Schema.Name

  @behaviour Avrora.Storage
  @content_type "application/vnd.schemaregistry.v1+json"

  @doc """
  Get schema by integer ID or by the subject name.

  If subject name was used by default the latest version will be used
  unless it explicitly given (e.g `io.acme.Payment:1`).

  ## Examples

      ...> {:ok, schema} = Avrora.Storage.Registry.get(1)
      ...> schema.full_name
      "io.acme.Payment"
      ...> {:ok, schema} = Avrora.Storage.Registry.get("io.acme.Payment")
      ...> schema.full_name
      "io.acme.Payment"
  """
  @impl true
  def get(key) when is_binary(key) do
    with {:ok, schema_name} <- Name.parse(key),
         {name, version} <- {schema_name.name, schema_name.version || "latest"},
         {:ok, response} <- http_client_get("subjects/#{name}/versions/#{version}"),
         {:ok, id} <- Map.fetch(response, "id"),
         {:ok, version} <- Map.fetch(response, "version"),
         {:ok, schema} <- Map.fetch(response, "schema"),
         {:ok, references} <- extract_references(response),
         {:ok, schema} <-
           SchemaEncoder.from_json(schema, name: name, reference_lookup_fun: make_reference_lookup_fun(references)) do
      Logger.debug("obtaining schema `#{schema_name.name}` with version `#{version}`")

      {:ok, %{schema | id: id, version: version}}
    end
  end

  def get(key) when is_integer(key) do
    with {:ok, response} <- http_client_get("schemas/ids/#{key}"),
         {:ok, schema} <- Map.fetch(response, "schema"),
         {:ok, references} <- extract_references(response),
         # TODO: Add note in the readme that:
         #       There is no such endpoint in registry versions < 5.5.0
         {:ok, response} <- http_client_get("schemas/ids/#{key}/versions"),
         {:ok, schema_name} <- extract_name(response),
         {:ok, schema} <-
           SchemaEncoder.from_json(schema,
             name: schema_name.name,
             reference_lookup_fun: make_reference_lookup_fun(references)
           ) do
      Logger.debug("obtaining schema and version with global id `#{key}`")

      {:ok, %{schema | id: key, version: schema_name.version}}
    end
  end

  @doc """
  Register new version of schema under subject name.

  ## Examples

      ...> schema = ~s({"fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}],"name":"Payment","namespace":"io.acme","type":"record"})
      ...> {:ok, schema} = Avrora.Storage.Registry.put("io.acme.examples.Payment", schema)
      ...> schema.full_name
      "io.acme.Payment"
  """
  @impl true
  def put(key, value) when is_binary(key) and is_binary(value) do
    with {:ok, schema_name} <- Name.parse(key),
         {:ok, response} <- http_client_post("subjects/#{schema_name.name}/versions", %{schema: value}),
         {:ok, id} <- Map.fetch(response, "id"),
         {:ok, schema} <- SchemaEncoder.from_json(value) do
      unless is_nil(schema_name.version) do
        Logger.warning("storing schema with version is not allowed, `#{schema_name.name}` used instead")
      end

      Logger.debug("new schema `#{schema_name.name}` stored with global id `#{id}`")

      {:ok, %{schema | id: id}}
    end
  end

  def put(_key, _value), do: {:error, :unsupported}

  @doc false
  @spec configured?() :: boolean()
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

  defp extract_name(response) do
    case response do
      [%{"subject" => name, "version" => version}] -> {:ok, %Name{name: name, version: version}}
      _ -> {:error, :invalid_versions}
    end
  end

  defp make_reference_lookup_fun(map) when map_size(map) == 0,
    do: &SchemaEncoder.reference_lookup/1

  defp make_reference_lookup_fun(references),
    do: &Map.fetch(references, &1)

  defp http_client_get(path) do
    if configured?(),
      do: path |> to_url() |> http_client().get(options()) |> handle(),
      else: {:error, :unconfigured_registry_url}
  end

  defp http_client_post(path, payload) do
    if configured?() do
      options = [{:content_type, @content_type} | options()]
      path |> to_url() |> http_client().post(payload, options) |> handle()
    else
      {:error, :unconfigured_registry_url}
    end
  end

  # NOTE: Maybe move to compile-time somehow?
  defp options do
    ssl_options =
      cond do
        !is_nil(registry_ssl_opts()) -> registry_ssl_opts()
        !is_nil(registry_ssl_cacerts()) -> [verify: :verify_peer, cacerts: [registry_ssl_cacerts()]]
        !is_nil(registry_ssl_cacert_path()) -> [verify: :verify_peer, cacertfile: registry_ssl_cacert_path()]
        true -> [verify: :verify_none]
      end

    [{:ssl_options, ssl_options} | headers()]
  end

  defp headers do
    authorization =
      case registry_auth() do
        {:basic, [username, password]} ->
          credentials = :base64.encode("#{username}:#{password}")
          [authorization: "Basic #{credentials}"]

        nil ->
          []
      end

    case registry_user_agent() do
      nil -> authorization
      user_agent -> [{:user_agent, user_agent} | authorization]
    end
  end

  defp to_url(path), do: "#{registry_url()}/#{path}"

  defp handle({:error, payload} = _response) when is_map(payload) do
    reason =
      case Map.get(payload, "error_code") do
        40401 -> :unknown_subject
        40402 -> :unknown_version
        40403 -> :unknown_schema
        42201 -> :invalid_schema
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
  defp registry_user_agent, do: Config.self().registry_user_agent()
  defp registry_ssl_opts, do: Config.self().registry_ssl_opts()
  defp registry_ssl_cacerts, do: Config.self().registry_ssl_cacerts()
  defp registry_ssl_cacert_path, do: Config.self().registry_ssl_cacert_path()
end
