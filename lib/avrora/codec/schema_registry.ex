defmodule Avrora.Codec.SchemaRegistry do
  @moduledoc """
  An Avro encoder/decoder working with a Schema Registry formatted Avro messages.

  It works with a binary format, which includes a required schema global ID inside the message.
  See more about [Schema Registry](https://docs.confluent.io/current/schema-registry/serializer-formatter.html#wire-format).
  """

  @behaviour Avrora.Codec
  @magic_bytes <<0::size(8)>>

  require Logger
  alias Avrora.{Codec, Resolver}

  @impl true
  def decodable?(payload) when is_binary(payload) do
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
        with {:ok, schema} <- Resolver.resolve_any(id),
             do: Codec.Plain.decode(body, schema: schema)

      _ ->
        {:error, :schema_not_found}
    end
  end

  @impl true
  def decode(payload, schema: schema) when is_binary(payload) do
    Logger.warn("message already contains embeded schema id, given schema will be ignored")

    case payload do
      <<@magic_bytes, <<id::size(32)>>, body::binary>> ->
        with {:ok, schema} <- Resolver.resolve_any([id, schema.full_name]),
             do: Codec.Plain.decode(body, schema: schema)

      _ ->
        {:error, :schema_not_found}
    end
  end

  # @impl true
  # def encode(payload, schema: schema) when is_map(payload) and is_nil(schema.id),
  #   do: {:error, :invalid_schema_id}

  @impl true
  def encode(payload, schema: schema) when is_map(payload) do
    if is_nil(schema.id) do
      {:error, :invalid_schema_id}
    else
      with {:ok, body} <- Codec.Plain.encode(payload, schema: schema) do
        encoded = <<@magic_bytes, <<schema.id::size(32)>>, body::binary>>

        {:ok, encoded}
      end
    end
  end
end
