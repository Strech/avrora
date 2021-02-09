defmodule Avrora.Utils.Registrar do
  @moduledoc """
  Memory store-aware schema registration with extended functionality
  designed to be used in the intensive loops.

  It gives you control over the name under which schema will be registered
  (i.e subject in Schema Registry) and allows you to enforce registration
  even if the schema exists.

  ## Examples

      defmodule Sample do
        alias Avrora.Utils.Registrar

        def loop do
          Enum.reduce_while(1..100, 0, fn x, acc ->
            if x < 100, do: {:cont, register("io.confluent.Payment")}, else: {:halt, acc}
          end)
        end

        defp register(schema_name), do: Registrar.register_schema_by_name(schema_name)
      end
  """

  require Logger
  alias Avrora.Config
  alias Avrora.Schema

  @doc """
  Register schema from local schema file in the Schema Registry.

  Schema name conventions inherited from `Avrora.Storage.File.get/1`.
  For extended documentation about registration process see `register_schema/2`.

  ## Options

  * `:as` - the name which will be used to register schema (i.e subject).
  * `:force` - the flag enforcing registration when schema was found
    in the Memory store (`false` by default).

  ## Examples

      ...> {:ok, schema} = Avrora.Utils.Registrar.register_schema_by_name("io.confluent.Payment", as: "NewName", force: true)
      ...> schema.full_name
      "io.confluent.Payment"
  """
  @spec register_schema_by_name(String.t(), as: String.t(), force: boolean) ::
          {:ok, Schema.t()} | {:error, term()}
  def register_schema_by_name(name, opts \\ []) do
    if Keyword.get(opts, :force, false) do
      with {:ok, schema} <- file_storage().get(name), do: register_schema(schema, opts)
    else
      with {:ok, nil} <- memory_storage().get(name),
           {:ok, schema} <- file_storage().get(name) do
        register_schema(schema, Keyword.put(opts, :force, true))
      end
    end
  end

  @doc """
  Register schema in the Schema Registry.

  This function relies on a Memory store before taking action.
  The most complete schema name will be looked at the store, i.e if the schema
  contains `version` then `full_name` + `version` will be used in prior just a `full_name`.

  ## Options

  * `:as` - the name which will be used to register schema (i.e subject).
  * `:force` - the flag enforcing registration when schema was found
    in the Memory store (`false` by default).

  ## Examples

      ...> {:ok, schema} = Avrora.Resolver.resolve("io.confluent.Payment")
      ...> {:ok, schema} = Avrora.Utils.Registrar.register_schema(schema, as: "NewName", force: true)
      ...> schema.full_name
      "io.confluent.Payment"
  """
  @spec register_schema(Schema.t(), as: String.t(), force: boolean) ::
          {:ok, Schema.t()} | {:error, term()}
  def register_schema(schema, opts \\ []) do
    full_name =
      if is_nil(schema.version),
        do: schema.full_name,
        else: "#{schema.full_name}:#{schema.version}"

    subject = Keyword.get(opts, :as, full_name)

    if Keyword.get(opts, :force, false) do
      do_register(subject, schema)
    else
      with {:ok, nil} <- memory_storage().get(full_name), do: do_register(subject, schema)
    end
  end

  defp do_register(subject, schema) do
    with {:ok, schema} <- registry_storage().put(subject, schema.json),
         {:ok, schema} <- memory_storage().put(schema.id, schema),
         {:ok, schema} <- memory_storage().put(schema.full_name, schema),
         {:ok, timestamp} <- memory_storage().expire(schema.full_name, names_ttl()) do
      if timestamp == :infinity,
        do: Logger.debug("schema `#{schema.full_name}` will be always resolved from memory")

      if is_nil(schema.version),
        do: {:ok, schema},
        else: memory_storage().put("#{schema.full_name}:#{schema.version}", schema)
    end
  end

  defp file_storage, do: Config.self().file_storage()
  defp memory_storage, do: Config.self().memory_storage()
  defp registry_storage, do: Config.self().registry_storage()
  defp names_ttl, do: Config.self().names_cache_ttl()
end
