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
         {:ok, schema} <- Schema.parse(schema) do
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
         {:ok, schema} <- Schema.parse(schema) do
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
  def configured?, do: !is_nil(Config.registry_url())

  defp handle_http_client(path, http_client_function) do
    with {:ok, url} <- handle_url(path),
         {:ok, headers} <- handle_headers() do
      url |> http_client_function.(headers) |> handle()
    end
  end

  defp http_client_get(path) do
    handle_http_client(path, fn url, headers ->
      http_client().get(url, headers: headers)
    end)
  end

  defp http_client_post(path, payload) do
    handle_http_client(path, fn url, headers ->
      http_client().post(url, payload, headers: headers, content_type: @content_type)
    end)
  end

  defp handle_url(path) do
    if configured?(),
      do: {:ok, to_url(path)},
      else: {:error, :unconfigured_registry_url}
  end

  defp handle_headers do
    with {:ok, authorization} <- auth() do
      {:ok, [authorization]}
    end
  end

  defp auth do
    case registry_auth() do
      nil ->
        {:ok, []}

      {:basic, file_path} = auth when is_binary(file_path) ->
        to_authorization(auth)

      {:basic, user, pass} = auth when is_binary(user) and is_binary(pass) ->
        to_authorization(auth)

      _unknown ->
        {:error, :malformed_registry_auth}
    end
  end

  defp to_authorization({:basic, path}) do
    [user, pass] = read_file_lines!(path, 2)
    to_authorization({:basic, user, pass})
  rescue
    File.Error ->
      Logger.warn("no such registry auth file found #{path}")
      {:error, :no_such_registry_auth_file}
  end

  defp to_authorization({:basic, user, pass}) do
    base64 = :base64.encode_to_string("#{user}:#{pass}")
    {:ok, {'Authorization', 'Basic #{base64}'}}
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

  defp registry_auth, do: Config.registry_auth()

  defp http_client, do: Config.http_client()

  defp read_file_lines!(path, lines) do
    File.stream!(path)
    |> Stream.take(lines)
    |> Stream.map(&String.trim/1)
    |> Enum.to_list()
  end
end
