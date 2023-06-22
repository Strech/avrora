defmodule Avrora.Encoder do
  @moduledoc """
  Wraps internal codec interface to add syntax sugar which will be exposed to client.
  """

  require Logger
  alias Avrora.Codec
  alias Avrora.Schema
  alias Avrora.Schema.Name

  @doc """
  Extract schema from the binary Avro message.

  ## Examples

      ...> payload = <<0, 0, 0, 0, 8, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48,
      48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48,
      48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
      ...> {:ok, schema} = Avrora.Encoder.extract_schema(payload)
      ...> schema.id
      42
      ...> schema.full_name
      "io.confluent.Payment"
  """
  @spec extract_schema(binary()) :: {:ok, Schema.t()} | {:error, term()}
  def extract_schema(payload) when is_binary(payload) do
    codec =
      [Codec.SchemaRegistry, Codec.ObjectContainerFile, Codec.Plain]
      |> Enum.find(& &1.is_decodable(payload))

    codec.extract_schema(payload)
  end

  @doc """
  Decode binary Avro message, loading schema from Schema Registry or Object Container Files.

  ## Examples

      ...> payload = <<0, 0, 0, 0, 8, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48,
      48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48,
      48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
      ...> Avrora.Encoder.decode(payload)
      {:ok, %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}}
  """
  @spec decode(binary()) :: {:ok, map() | list(map())} | {:error, term()}
  def decode(payload) when is_binary(payload) do
    codec =
      [Codec.SchemaRegistry, Codec.ObjectContainerFile, Codec.Plain]
      |> Enum.find(& &1.is_decodable(payload))

    codec.decode(payload)
  end

  @doc """
  Decode binary Avro message, loading schema from local file or Schema Registry.

  ## Examples

      ...> payload = <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45,
      48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48,
      48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
      ...> Avrora.Encoder.decode(payload, schema_name: "io.confluent.Payment")
      {:ok, %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}}
  """
  @spec decode(binary(), schema_name: String.t()) :: {:ok, map() | list(map())} | {:error, term()}
  def decode(payload, schema_name: schema_name) when is_binary(payload) do
    with {:ok, schema_name} <- Name.parse(schema_name) do
      unless is_nil(schema_name.version) do
        Logger.warning("decoding with schema version is not supported, `#{schema_name.name}` used instead")
      end

      schema = %Schema{full_name: schema_name.name}

      codec =
        [Codec.SchemaRegistry, Codec.ObjectContainerFile, Codec.Plain]
        |> Enum.find(& &1.is_decodable(payload))

      if codec == Codec.Plain do
        Logger.warning(
          "`Avrora.Encoder.decode/2` with plain format is deprecated, use `Avrora.Encoder.decode_plain/2` instead"
        )
      end

      codec.decode(payload, schema: schema)
    end
  end

  @doc """
  Decode binary Avro message with a :plain format and load schema from local file.

  ## Examples

      ...> payload = <<0, 232, 220, 144, 233, 11, 200, 1>>
      ...> Avrora.Encoder.decode_plain(payload,"io.confluent.NumericTransfer")
      {:ok, %{"link_is_enabled" => false, "updated_at" => 1586632500, "updated_by_id" => 100}
  """
  @spec decode_plain(binary(), schema_name: String.t()) :: {:ok, map()} | {:error, term()}
  def decode_plain(payload, schema_name: schema_name) when is_binary(payload) do
    with {:ok, schema_name} <- Name.parse(schema_name) do
      unless is_nil(schema_name.version) do
        Logger.warning("decoding with schema version is not supported, `#{schema_name.name}` used instead")
      end

      Codec.Plain.decode(payload, schema: %Schema{full_name: schema_name.name})
    end
  end

  @doc """
  Encode message map in Avro format, loading schema from local file or Schema Registry.

  The `:format` argument controls output format:

  * `:plain` - Just return Avro binary data, with no header or embedded schema
  * `:ocf` - Use [Object Container File]https://avro.apache.org/docs/1.8.1/spec.html#Object+Container+Files)
    format, embedding the full schema with the data
  * `:registry` - Write data with Confluent Schema Registry
    [Wire Format](https://docs.confluent.io/current/schema-registry/serializer-formatter.html#wire-format),
    which prefixes the data with the schema id
  * `:guess` - Use `:registry` if possible, otherwise use `:ocf` (default)

  ## Examples

      ...> payload = %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
      ...> Avrora.Encoder.encode(payload, schema_name: "io.confluent.Payment", format: :plain)
      {:ok, <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45,
            48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48,
            48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>}
  """
  @spec encode(map(), schema_name: String.t(), format: :guess | :registry | :ocf | :plain) ::
          {:ok, binary()} | {:error, term()}
  def encode(payload, schema_name: schema_name) when is_map(payload),
    do: encode(payload, schema_name: schema_name, format: :guess)

  def encode(payload, schema_name: schema_name, format: format) when is_map(payload) do
    with {:ok, schema_name} <- Name.parse(schema_name) do
      if format == :plain do
        Logger.warning(
          "`Avrora.Encoder.encode/2` with `format: :plain` is deprecated, use `Avrora.Encoder.encode_plain/2` instead"
        )
      end

      unless is_nil(schema_name.version) do
        Logger.warning("encoding with schema version is not supported yet, `#{schema_name.name}` used instead")
      end

      schema = %Schema{full_name: schema_name.name}

      case format do
        :guess ->
          with {:error, _} <- Codec.SchemaRegistry.encode(payload, schema: schema),
               do: Codec.ObjectContainerFile.encode(payload, schema: schema)

        :registry ->
          Codec.SchemaRegistry.encode(payload, schema: schema)

        :ocf ->
          Codec.ObjectContainerFile.encode(payload, schema: schema)

        :plain ->
          Codec.Plain.encode(payload, schema: schema)

        _ ->
          {:error, :unknown_format}
      end
    end
  end

  @doc """
  Encode binary Avro message with a :plain format and load schema from local file.

  ## Examples

      ...> payload = %{"link_is_enabled" => false, "updated_at" => 1586632500, "updated_by_id" => 100}
      ...> Avrora.Encoder.encode_plain(payload,"io.confluent.NumericTransfer")
      {:ok, <<0, 232, 220, 144, 233, 11, 200, 1>>}
  """
  @spec encode_plain(map(), schema_name: String.t()) :: {:ok, binary()} | {:error, term()}
  def encode_plain(payload, schema_name: schema_name) when is_map(payload) do
    with {:ok, schema_name} <- Name.parse(schema_name) do
      unless is_nil(schema_name.version) do
        Logger.warning(
          "encoding with schema version is not supported for plain format, `#{schema_name.name}` used instead"
        )
      end

      Codec.Plain.encode(payload, schema: %Schema{full_name: schema_name.name})
    end
  end
end
