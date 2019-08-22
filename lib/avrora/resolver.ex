defmodule Avrora.Resolver do
  @moduledoc """
  Resolves schema names or global ID's to a specific schema files while keeping
  memory and registry storage up to date.
  """

  require Logger
  alias Avrora.{Config, Name}

  @doc """
  Resolves schema by either global ID or name (can contain version).

  It will return first successful resolution result with order:

    * Avrora.Resolver.resolve/1 when integer
    * Avrora.Resolver.resolve/1 when binary

  ## Examples

      ...> {:ok, avro} = Avrora.Resolver.resolve_any(1, "io.confluent.Payment")
      ...> {_, _, _, _, _, _, full_name, _} = avro.schema
      ...> full_name
      "io.confluent.Payment"
  """
  @spec resolve_any(integer(), String.t()) :: {:ok, Avrora.Schema.t()} | {:error, term()}
  def resolve_any(id, name) do
    case resolve(id) do
      {:ok, avro} ->
        {:ok, avro}

      _ ->
        Logger.debug("fail to resolve by id `#{id}`, will fallback to name `#{name}`")
        resolve(name)
    end
  end

  @doc """
  Resolves schema by a global ID.

  After schema being resolved it will be stored in memory storage
  with key equal to `global ID`.

  ## Examples

      iex> {:ok, avro} = Avrora.Resolver.resolve(1)
      iex> {_, _, _, _, _, _, full_name, _} = avro.schema
      iex> full_name
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

      ...> {:ok, avro1} = Avrora.Resolver.resolve("io.confluent.Payment")
      ...> {:ok, avro2} = Avrora.Resolver.resolve("io.confluent.Payment:42")
      ...> avro1.version
      42
      ...> avro2.version
      42
      ...> {_, _, _, _, _, _, full_name1, _} = avro1.schema
      ...> full_name1
      "io.confluent.Payment"
      ...> {_, _, _, _, _, _, full_name2, _} = avro2.schema
      ...> full_name2
      "io.confluent.Payment"
  """
  @spec resolve(String.t()) :: {:ok, Avrora.Schema.t()} | {:error, term()}
  def resolve(name) when is_binary(name) do
    with {:ok, schema_name} = Name.parse(name),
         {:ok, nil} <- memory_storage().get(name) do
      case registry_storage().get(name) do
        {:ok, avro} ->
          with {:ok, avro} <- memory_storage().put(avro.id, avro) do
            memory_storage().put("#{schema_name.name}:#{avro.version}", avro)
          end

        {:error, :unknown_subject} ->
          with {:ok, avro} <- file_storage().get(schema_name.name),
               {:ok, avro} <- registry_storage().put(schema_name.name, avro.raw_schema) do
            memory_storage().put(avro.id, avro)
          end

        {:error, :unconfigured_registry_url} ->
          with {:ok, avro} <- file_storage().get(name),
               do: memory_storage().put(schema_name.name, avro)

        {:error, reason} ->
          {:error, reason}
      end
    end
  end

  defp file_storage, do: Config.file_storage()
  defp memory_storage, do: Config.memory_storage()
  defp registry_storage, do: Config.registry_storage()
end
