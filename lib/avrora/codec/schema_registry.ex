defmodule Avrora.Codec.SchemaRegistry do
  @moduledoc """
  An Avro encoder/decoder working with a Schema Registry formatted Avro messages.

  It works with a binary format, which includes a required schema global ID inside the message.
  See more about [Schema Registry](https://docs.confluent.io/current/schema-registry/serializer-formatter.html#wire-format).
  """

  @behaviour Avrora.Codec
  @magic_bytes <<0::size(8)>>

  require Logger
  alias Avrora.{Codec, Resolver, Schema}

  @impl true
  def compatible?(payload) when is_binary(payload) do
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
          Logger.warn(
            "message already contains embeded schema id, given schema id will be ignored"
          )
        end

        schema = %Schema{schema | id: id}
        with {:ok, schema} <- resolve(schema), do: Codec.Plain.decode(body, schema: schema)

      _ ->
        {:error, :schema_not_found}
    end
  end

  @impl true
  def encode(payload, schema: schema) when is_map(payload) do
    # TODO: Should we try to resolve the schema with only name to get ID?
    #       it will allow us to remove Resolve on the level of encoder
    if is_nil(schema.id),
      do: {:error, :invalid_schema_id},
      else: do_encode(payload, schema)
  end

  defp do_encode(payload, schema) do
    with {:ok, schema} <- resolve(schema),
         {:ok, body} <- Codec.Plain.encode(payload, schema: schema) do
      encoded = <<@magic_bytes, <<schema.id::size(32)>>, body::binary>>

      {:ok, encoded}
    end
  end

  defp resolve(schema) do
    cond do
      Schema.usable?(schema) ->
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
