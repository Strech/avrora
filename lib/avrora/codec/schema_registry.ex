defmodule Avrora.Codec.SchemaRegistry do
  @moduledoc """
  An Avro encoder/decoder working with a Schema Registry formatted Avro messages.

  It works with a binary format, which includes a required schema global ID inside the message.
  See more about [Schema Registry](https://docs.confluent.io/current/schema-registry/serializer-formatter.html#wire-format).
  """

  @behaviour Avrora.Codec
  @magic_bytes <<0::size(8)>>

  alias Avrora.Resolver

  @impl true
  def decodable?(payload) when is_binary(payload) do
    case payload do
      <<@magic_bytes, _::binary>> -> true
      _ -> false
    end
  end

  @impl true
  def extract_schema(payload) do
    case payload do
      <<@magic_bytes, <<id::size(32)>>, _::binary>> -> Resolver.resolve(id)
      _ -> {:error, :schema_not_found}
    end
  end

  @impl true
  def decode(payload, opts \\ []) when is_binary(payload) do
    {:error, :TODO}
  end

  @impl true
  def encode(payload, schema: schema) when is_map(payload) do
    {:error, :TODO}
  end
end
