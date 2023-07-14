defmodule Avrora.Codec.SchemaRegistry do
  @moduledoc """
  An Avro encoder/decoder working with a Schema Registry formatted Avro messages.

  It works with a binary format, which includes a required schema global ID inside the message.
  See more about [Schema Registry](https://docs.confluent.io/current/schema-registry/serializer-formatter.html#wire-format).
  """

  @behaviour Avrora.Codec
  @magic_bytes <<0::size(8)>>

  require Logger
  alias Avrora.Codec
  alias Avrora.Resolver
  alias Avrora.Schema

  @impl true
  def is_decodable(payload) when is_binary(payload) do
    case payload do
      <<@magic_bytes, _::binary>> -> true
      _ -> false
    end
  end

  @impl true
  def extract_schema(payload) when is_binary(payload) do
    case payload do
      <<@magic_bytes, <<id::size(32)>>, _::binary>> -> Resolver.resolve(id)
      _ -> {:error, :schema_not_found}
    end
  end

  @impl true
  def decode(payload) when is_binary(payload) do
    case payload do
      <<@magic_bytes, <<id::size(32)>>, body::binary>> ->
        with {:ok, schema} <- Resolver.resolve(id),
             do: Codec.Plain.decode(body, schema: schema)

      _ ->
        {:error, :schema_not_found}
    end
  end

  @impl true
  def decode(payload, schema: schema) when is_binary(payload) do
    case payload do
      <<@magic_bytes, <<id::size(32)>>, body::binary>> ->
        unless is_nil(schema.id) do
          Logger.warning("message already contains embeded schema id, given schema id will be ignored")
        end

        schema = %Schema{schema | id: id}

        with {:ok, schema} <- resolve(schema) do
          if id != schema.id do
            Logger.warning("message embeded schema id is different from the resolved and used schema id")
          end

          Codec.Plain.decode(body, schema: schema)
        end

      _ ->
        {:error, :schema_not_found}
    end
  end

  @impl true
  def encode(payload, schema: schema) when is_binary(payload) or is_map(payload) do
    with {:ok, schema} <- resolve(schema) do
      schema = if is_nil(schema.id), do: {:error, :invalid_schema_id}, else: {:ok, schema}

      with {:ok, schema} <- schema,
           {:ok, body} <- Codec.Plain.encode(payload, schema: schema) do
        encoded = <<@magic_bytes, <<schema.id::size(32)>>, body::binary>>

        {:ok, encoded}
      end
    end
  end

  defp resolve(schema) do
    cond do
      is_integer(schema.id) && is_binary(schema.full_name) && is_reference(schema.lookup_table) ->
        {:ok, schema}

      is_integer(schema.id) && is_binary(schema.full_name) ->
        Resolver.resolve_any([schema.id, schema.full_name])

      is_integer(schema.id) ->
        Resolver.resolve(schema.id)

      is_binary(schema.full_name) ->
        Resolver.resolve(schema.full_name)

      true ->
        {:error, :unusable_schema}
    end
  end
end
