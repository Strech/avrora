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
         {:ok, schema} <- Map.fetch(response, "schema") do
      case Map.has_key?(response, "references") do
        true ->
          with {:ok, schema} <- get_with_references(response) do
            Logger.debug("obtaining schema (with reference) `#{schema_name.name}` with version `#{version}`")

            {:ok, %{schema | id: id, version: version}}
          end

        false ->
          with {:ok, schema} <- Schema.parse(schema) do
            Logger.debug("obtaining schema `#{schema_name.name}` with version `#{version}`")

            {:ok, %{schema | id: id, version: version}}
          end
      end
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
    with {:ok, response} <- http_client_get("schemas/ids/#{key}") do

      case Map.has_key?(response, "references") do
        true ->
          with {:ok, schema} <- get_with_references(response) do
            Logger.debug("obtaining schema (with reference) with global id `#{key}`")

            {:ok, %{schema | id: key}}
          end

        false ->
          with {:ok, schema} <- Map.fetch(response, "schema"),
               {:ok, schema} <- Schema.parse(schema) do
            Logger.debug("obtaining schema with global id `#{key}`")

            {:ok, %{schema | id: key}}
          end
      end
    end
  end

  defp get_with_references(response) do
    with {:ok, references} <- Map.fetch(response, "references"),
         {:ok, schema} <- Map.fetch(response, "schema"),
         {:ok, decoded_schema} = Jason.decode(schema) do
      schema_with_references =
        Enum.reduce(references, decoded_schema, fn r, merged_schema ->
          replace_schema(r, merged_schema)
        end)

      Schema.parse(schema_with_references)
    end
  end

  defp replace_schema(reference, decoded_schema) do
    schema_fields = decoded_schema["fields"]

    find_schema =
      &(&1["type"] == reference["name"] ||
          &1["type"] == List.last(String.split(reference["name"], ".")))

    schema_to_replace_index = Enum.find_index(schema_fields, &find_schema.(&1))

    type_to_include =
      schema_fields
      |> Enum.find(&find_schema.(&1))
      |> Map.put("type", get_reference_schema_to_include(reference["subject"]))

    new_fields =
      schema_fields
      |> List.replace_at(schema_to_replace_index, type_to_include)

    {:ok, decoded_schema} =
      decoded_schema
      |> Map.put("fields", new_fields)
      |> Jason.encode()

    decoded_schema
  end

  defp get_reference_schema_to_include(subject_name) do
    with {:ok, reference_schema} <- get(subject_name),
         {:ok, reference_schema_json} <- Jason.decode(reference_schema.json) do
      reference_schema_json
      |> Map.delete("namespace")
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
