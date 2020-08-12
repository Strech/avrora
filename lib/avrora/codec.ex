defmodule Avrora.Codec do
  @moduledoc """
  A behaviour for encoding/decoding Avro messages.
  """

  @doc """
  Check either a given binary Avro message is decodable with a specific codec or not.

  NOTE: It's not guaranteed that a decodable binary message will be
        successfuly decoded.

  ## Examples

      ...> Avrora.Codec.Plain.decodable?(<<1, 2, 3>>)
      true
      ...> Avrora.Codec.Plain.decodable?(123_123)
      false
  """
  @callback decodable?(payload :: binary()) :: boolean

  @doc """
  Extract schema from the binary Avro message.

  ## Examples

      ...> payload = <<0, 0, 0, 0, 8, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48,
      48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48,
      48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
      ...> {:ok, schema} = Avrora.Codec.SchemaRegistry.extract_schema(payload)
      ...> schema.id
      42
      ...> schema.full_name
      "io.confluent.Payment"
  """
  @callback extract_schema(payload :: binary()) ::
              {:ok, result :: Avrora.Schema.t()} | {:error, reason :: term()}

  @doc """
  Decode a binary Avro message into the Elixir data.

  ## Examples

      ...> payload = <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48,
      45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48,
      48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
      ...> {:ok, schema} = Avrora.Resolver.resolve("io.confluent.Payment")
      ...> Avrora.Codec.Plain.decode(payload, schema: schema)
      {:ok, %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}}

  """
  @callback decode(payload :: binary(), options :: keyword(Avrora.Schema.t())) ::
              {:ok, result :: map() | list(map())} | {:error, reason :: term()}

  @doc """
  Encode the Elixir data into a binary Avro message.

  ## Examples

      ...> payload = %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
      ...> {:ok, schema} = Avrora.Resolver.resolve("io.confluent.Payment")
      ...> Avrora.Codec.Plain.encode(payload, schema: schema)
      <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48,
      48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
  """
  @callback encode(payload :: map(), options :: keyword(Avrora.Schema.t())) ::
              {:ok, result :: binary()} | {:error, reason :: term()}
end
