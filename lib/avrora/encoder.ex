defmodule Avrora.Encoder do
  @moduledoc """
  Encodes and decodes avro messages created with or without extra Schema Registry
  version.
  """

  require Logger
  alias Avrora.{Mapper, Name, Resolver}

  @registry_magic_bytes <<0::size(8)>>
  @object_container_magic_bytes <<"Obj", 1>>

  @doc """
  Decodes given message with a schema eather loaded from the Object Container Files
  or from the configured schema registry.

  ## Examples

      ...> payload = <<0, 0, 0, 0, 8, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48,
      48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48,
      48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
      ...> Avrora.Encoder.decode(payload)
      {:ok, %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}}
  """
  @spec decode(binary()) :: {:ok, map()} | {:error, term()}
  def decode(payload) when is_binary(payload) do
    case payload do
      <<@registry_magic_bytes, <<id::size(32)>>, body::binary>> ->
        with {:ok, avro} <- Resolver.resolve(id), do: do_decode(avro.schema, body)

      <<@object_container_magic_bytes, _::binary>> ->
        do_decode(payload)

      _ ->
        {:error, :undecodable}
    end
  end

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
  def decode(payload, schema_name: schema_name) when is_binary(payload) do
    with {:ok, schema_name} <- Name.parse(schema_name) do
      unless is_nil(schema_name.version) do
        Logger.warn(
          "decoding message with schema version is not supported, `#{schema_name.name}` used instead"
        )
      end

      {schema_id, body} =
        case payload do
          <<@registry_magic_bytes, <<id::size(32)>>, body::binary>> ->
            Logger.warn("message contains embeded global id, given schema name will be ignored")
            {id, body}

          <<@object_container_magic_bytes, _::binary>> ->
            Logger.warn("message contains embeded schema, given schema name will be ignored")
            {:embeded, payload}

          <<body::binary>> ->
            {schema_name.name, body}
        end

      case schema_id do
        :embeded ->
          do_decode(payload)

        _ ->
          with {:ok, avro} <- Resolver.resolve_any([schema_id, schema_name.name]),
               do: do_decode(avro.schema, body)
      end
    end
  end

  @doc """
  Encodes given message with a schema eather loaded from the local file or from
  the configured schema registry.

  You can control formatting with a `:format` option, possible variants are:

  * :guess - behaves like :ocf if can't behave like :registry (default)
  * :ocf - embeds schema with Object Container Files format
  * :registry - embeds Confluent Schema Registry magic version
  * :plain - gives nothing, but only encoded message

  ## Examples

      ...> payload = %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
      ...> Avrora.Encoder.encode(payload, schema_name: "io.confluent.Payment", format: :plain)
      {:ok, <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45,
            48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48,
            48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>}
  """
  @spec encode(map(), keyword(String.t())) :: {:ok, binary()} | {:error, term()}
  def encode(payload, schema_name: schema_name) when is_map(payload),
    do: encode(payload, schema_name: schema_name, format: :guess)

  def encode(payload, schema_name: schema_name, format: format) when is_map(payload) do
    with {:ok, schema_name} <- Name.parse(schema_name),
         {:ok, avro} <- Resolver.resolve(schema_name.name),
         {:ok, body} <- do_encode(avro.schema, payload) do
      unless is_nil(schema_name.version) do
        Logger.warn(
          "encoding message with schema version is not supported yet, `#{schema_name.name}` used instead"
        )
      end

      case format do
        :guess ->
          if is_nil(avro.id),
            do: do_embed_schema(avro.schema, body),
            else: do_embed_id(avro.id, body)

        :registry ->
          if is_nil(avro.id),
            do: {:error, :invalid_schema_id},
            else: do_embed_id(avro.id, body)

        :ocf ->
          do_embed_schema(avro.schema, body)

        :plain ->
          {:ok, body}

        _ ->
          {:error, :unknown_format}
      end
    end
  end

  defp do_decode(payload) do
    {_, _, decoded} = :avro_ocf.decode_binary(payload)

    {:ok, Mapper.to_map(decoded)}
  rescue
    error -> {:error, error}
  end

  defp do_decode(schema, payload) do
    decoded =
      payload
      |> :avro_binary_decoder.decode(:undefined, fn _ -> schema end)
      |> Mapper.to_map()

    {:ok, decoded}
  rescue
    error -> {:error, error}
  end

  defp do_encode(schema, payload) do
    encoded =
      schema
      |> :avro_record.new(payload)
      |> :avro_binary_encoder.encode_value()
      |> :erlang.list_to_binary()

    {:ok, encoded}
  rescue
    error -> {:error, error}
  end

  defp do_embed_id(id, payload) do
    encoded = <<@registry_magic_bytes, <<id::size(32)>>, payload::binary>>

    {:ok, encoded}
  end

  defp do_embed_schema(schema, payload) do
    encoded =
      schema
      |> :avro_ocf.make_header()
      |> :avro_ocf.make_ocf(List.wrap(payload))
      |> :erlang.list_to_binary()

    {:ok, encoded}
  rescue
    error -> {:error, error}
  end
end
