defmodule Avrora.Resolver do
  @moduledoc """
  Resolves schema names or global ID's to a specific schema files while keeping
  memory and registry storage up to date.
  """

  require Logger
  alias Avrora.{Config, Name}

  @doc """
  Resolves schema by all given possible identifiers.
  It will return first successful resolution or the last error.

  To resolve schema it uses:

    * Avrora.Resolver.resolve/1 when integer
    * Avrora.Resolver.resolve/1 when binary

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
  Resolves schema by a global ID.

  After schema being resolved it will be stored in memory storage
  with key equal to `global ID`.

  ## Examples

      iex> {:ok, schema} = Avrora.Resolver.resolve(1)
      iex> schema.full_name
      "io.confluent.Payment"
  """
  @spec resolve(integer()) :: {:ok, Avrora.Schema.t()} | {:error, term()}
  def resolve(id) when is_integer(id) do
    with {:ok, nil} <- memory_storage().get(id),
         {:ok, avro} <- registry_storage().get(id) do
      memory_storage().put(id, avro)
    end
  end

  @doc """
  Resolves schema be it's name and optionally version. A version could be provided
  by adding `:` and version number to the name (i.e `io.confluent.Payment:5`).

  In case if confluent schema registry url is configured, resolution will take a
  look there first and in case of failure try to read schema from the configured
  schemas folder.

  After schema being resolved it will be stored in memory storage with
  key equal `name` and `name:version`. Also it will be added to the registry if
  it's configured.

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
  @spec resolve(String.t()) :: {:ok, Avrora.Schema.t()} | {:error, term()}
  def resolve(name) when is_binary(name) do
    with {:ok, schema_name} = Name.parse(name),
         {:ok, nil} <- memory_storage().get(name) do
      case registry_storage().get(name) do
        {:ok, schema} ->
          with {:ok, schema} <-
                 memory_storage().put("#{schema_name.name}:#{schema.version}", schema),
               {:ok, schema} <- memory_storage().put(schema_name.name, schema),
               {:ok, timestamp} = memory_storage().expire(schema_name.name, names_ttl()) do
            if timestamp == :infinity,
              do: Logger.debug("schema `#{schema_name.name}` will be always resolved from memory")

            memory_storage().put(schema.id, schema)
          end

        {:error, :unknown_subject} ->
          with {:ok, schema} <- file_storage().get(schema_name.name),
               {:ok, schema} <- registry_storage().put(schema_name.name, schema.json),
               {:ok, schema} <- memory_storage().put(schema_name.name, schema),
               {:ok, timestamp} = memory_storage().expire(schema_name.name, names_ttl()) do
            if timestamp == :infinity,
              do: Logger.debug("schema `#{schema_name.name}` will be always resolved from memory")

            memory_storage().put(schema.id, schema)
          end

        {:error, :unconfigured_registry_url} ->
          with {:ok, schema} <- file_storage().get(name),
               do: memory_storage().put(schema_name.name, schema)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp file_storage, do: Config.file_storage()
  defp memory_storage, do: Config.memory_storage()
  defp registry_storage, do: Config.registry_storage()
  defp names_ttl, do: Config.names_cache_ttl()
end
