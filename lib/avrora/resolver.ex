defmodule Avrora.Resolver do
  @moduledoc """
  Resolve schema name or global ID to a schema, keeping cache up to date.
  """

  require Logger
  alias Avrora.Config
  alias Avrora.Schema.Name

  @doc """
  Resolve schema, trying multiple methods. First tries integer id, then string name.

  ## Examples

      ...> {:ok, schema} = Avrora.Resolver.resolve_any([1, "io.confluent.Payment"])
      ...> schema.full_name
      "io.confluent.Payment"
  """
  @spec resolve_any(nonempty_list(integer() | String.t())) ::
          {:ok, Avrora.Schema.t()} | {:error, term()}
  def resolve_any(ids) do
    ids = List.wrap(ids)
    total = Enum.count(ids)

    ids
    |> Stream.map(&{&1, resolve(&1)})
    |> Stream.with_index(1)
    |> Enum.find_value(fn {{id, {status, result}}, index} ->
      if status == :error, do: Logger.debug("fail to resolve schema by identifier `#{id}`")
      if status == :ok || index == total, do: {status, result}
    end)
  end

  @doc """
  Resolve schema by integer ID or by a string name with optional version,
  then update memory storage.

  In case of an integer ID it stores schema in memory with ID key.

  ## Examples

      ...> {:ok, schema} = Avrora.Resolver.resolve(1)
      ...> schema.full_name
      "io.confluent.Payment"

  In case of a string name it stores schema in memory with key `name` and `name:version`,
  also adds schema to the Schema Registry (if it's configured).

  A version for the name can be provided by adding `:` with the version number,
  e.g. `io.confluent.Payment:5`. If the Schema Registry is configured (`:registry_url`),
  it will first try fetch there, then local schemas folder (`:schemas_path`).

  ## Examples

      ...> {:ok, schema1} = Avrora.Resolver.resolve("io.confluent.Payment")
      ...> {:ok, schema2} = Avrora.Resolver.resolve("io.confluent.Payment:42")
      ...> schema1.version
      42
      ...> schema2.version
      42
      ...> schema1.full_name
      "io.confluent.Payment"
      ...> schema.full_name
      "io.confluent.Payment"

  """
  @spec resolve(integer() | String.t()) :: {:ok, Avrora.Schema.t()} | {:error, term()}
  def resolve(id) when is_integer(id) do
    with {:ok, nil} <- memory_storage().get(id),
         {:ok, avro} <- registry_storage().get(id) do
      memory_storage().put(id, avro)
    end
  end

  def resolve(name) when is_binary(name) do
    with {:ok, schema_name} <- Name.parse(name),
         {:ok, nil} <- memory_storage().get(name) do
      case resolve_with_registry(schema_name) do
        {:ok, schema} ->
          with {:ok, schema} <- memory_storage().put(schema.id, schema),
               {:ok, schema} <- memory_storage().put(schema_name.name, schema),
               {:ok, timestamp} <- memory_storage().expire(schema_name.name, names_ttl()) do
            if timestamp == :infinity,
              do: Logger.debug("schema `#{schema_name.name}` will be always resolved from memory")

            if is_nil(schema.version),
              do: {:ok, schema},
              else: memory_storage().put("#{schema_name.name}:#{schema.version}", schema)
          end

        {:reclaim, schema} ->
          memory_storage().put(schema_name.name, schema)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp resolve_with_registry(schema_name) do
    if Config.self().registry_schemas_autoreg() && is_nil(schema_name.version) do
      with {:ok, schema} <- file_storage().get(schema_name.origin),
           {:error, :unconfigured_registry_url} <-
             registry_storage().put(schema_name.name, schema.json),
           do: {:reclaim, schema}
    else
      with {:error, :unconfigured_registry_url} <- registry_storage().get(schema_name.origin),
           {:ok, schema} <- file_storage().get(schema_name.origin),
           do: {:reclaim, schema}
    end
  end

  defp file_storage, do: Config.self().file_storage()
  defp memory_storage, do: Config.self().memory_storage()
  defp registry_storage, do: Config.self().registry_storage()
  defp names_ttl, do: Config.self().names_cache_ttl()
end
