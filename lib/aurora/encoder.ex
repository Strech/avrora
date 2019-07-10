defmodule Avrora.Encoder do
  @moduledoc """
  Encodes and decodes avro messages created with or without extra Schema Registry
  version.
  """

  require Logger
  alias Avrora.{Name, Resolver}

  @registry_magic_byte <<0::size(8)>>

  @doc """
  Decodes given message with a schema eather loaded from the local file or from
  the configured schema registry.

  ## Examples

      ...> payload = <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45,
      48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48,
      48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
      ...> Avrora.Encoder.decode(payload, schema_name: "io.confluent.Payment")
      {:ok, %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}}
  """
  @spec decode(binary(), keyword(String.t())) :: {:ok, map()} | {:error, term()}
  def decode(payload, schema_name: schema_name) do
    with {:ok, schema_name} <- Name.parse(schema_name) do
      unless is_nil(schema_name.version) do
        Logger.warn(
          "decoding message with schema version is not allowed, `#{schema_name.name}` used instead"
        )
      end

      {schema_name, body} =
        case payload do
          <<@registry_magic_byte, <<version::size(32)>>, body::binary>> ->
            {"#{schema_name.name}:#{version}", body}

          <<body::binary>> ->
            {schema_name.name, body}
        end

      with {:ok, avro} <- Resolver.resolve(schema_name), do: AvroEx.decode(avro.ex_schema, body)
    end
  end

  @doc """
  Encodes given message with a schema eather loaded from the local file or from
  the configured schema registry.

  ## Examples

      ...> payload = %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
      ...> Avrora.Encoder.encode(payload, schema_name: "io.confluent.Payment")
      {:ok, <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45,
            48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48,
            48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>}
  """
  @spec encode(map(), keyword(String.t())) :: {:ok, binary} | {:error, term()}
  def encode(payload, schema_name: schema_name) when is_map(payload) do
    with {:ok, schema_name} <- Name.parse(schema_name),
         {:ok, avro} <- Resolver.resolve(schema_name.name),
         {:ok, body} <- AvroEx.encode(avro.ex_schema, payload) do
      unless is_nil(schema_name.version) do
        Logger.warn(
          "encoding message with schema version is not allowed, `#{schema_name.name}` used instead"
        )
      end

      body =
        if is_nil(avro.version),
          do: body,
          else: <<@registry_magic_byte, <<avro.version::size(32)>>, body::binary>>

      {:ok, body}
    end
  end
end
