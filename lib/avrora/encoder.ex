defmodule Avrora.Encoder do
  @moduledoc """
  Encode and decode binary Avro messages.
  """

  require Logger
  alias Avrora.ObjectContainerFile
  alias Avrora.{Mapper, Resolver, Schema}
  alias Avrora.Schema.Name

  @registry_magic_bytes <<0::size(8)>>
  @object_container_magic_bytes <<"Obj", 1>>
  @decoder_options %{
    encoding: :avro_binary,
    hook: &__MODULE__.__hook__/4,
    is_wrapped: true,
    map_type: :proplist,
    record_type: :map
  }

  @doc """
  Extract schema from binary Avro

  ## Examples

      ...> payload = <<0, 0, 0, 0, 8, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48,
      48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48,
      48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
      ...> Avrora.Encoder.extract_schema(payload)
      {:ok, %Avrora.Schema{"full_name" => "io.confluent.Payment", "id" => 42}}
  """
  def extract_schema(payload) when is_binary(payload) do
    case payload do
      <<@registry_magic_bytes, <<id::size(32)>>, _body::binary>> ->
        Resolver.resolve(id)

      <<@object_container_magic_bytes, _::binary>> ->
        ObjectContainerFile.extract_schema(payload)

      _ ->
        {:error, :schema_not_found}
    end
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
    case payload do
      <<@registry_magic_bytes, <<id::size(32)>>, body::binary>> ->
        with {:ok, schema} <- Resolver.resolve(id), do: do_decode(schema, body)

      <<@object_container_magic_bytes, _::binary>> ->
        do_decode(payload)

      _ ->
        {:error, :undecodable}
    end
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
  @spec decode(binary(), keyword(String.t())) :: {:ok, map() | list(map())} | {:error, term()}
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
          with {:ok, schema} <- Resolver.resolve_any([schema_id, schema_name.name]),
               do: do_decode(schema, body)
      end
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
  @spec encode(map(), keyword(String.t())) :: {:ok, binary()} | {:error, term()}
  def encode(payload, schema_name: schema_name) when is_map(payload),
    do: encode(payload, schema_name: schema_name, format: :guess)

  def encode(payload, schema_name: schema_name, format: format) when is_map(payload) do
    with {:ok, schema_name} <- Name.parse(schema_name),
         {:ok, schema} <- Resolver.resolve(schema_name.name),
         {:ok, body} <- do_encode(schema, payload) do
      unless is_nil(schema_name.version) do
        Logger.warn(
          "encoding message with schema version is not supported yet, `#{schema_name.name}` used instead"
        )
      end

      case format do
        :guess ->
          if is_nil(schema.id),
            do: do_embed_schema(schema, body),
            else: do_embed_id(schema.id, body)

        :registry ->
          if is_nil(schema.id),
            do: {:error, :invalid_schema_id},
            else: do_embed_id(schema.id, body)

        :ocf ->
          do_embed_schema(schema, body)

        :plain ->
          {:ok, body}

        _ ->
          {:error, :unknown_format}
      end
    end
  end

  # NOTE: `erlavro` supports setting a decoder hook, but we don't, at least for now
  @doc false
  def __hook__(_type, _sub_name_or_id, data, decode_fun), do: decode_fun.(data)

  defp do_decode(payload) do
    {_, _, decoded} = :avro_ocf.decode_binary(payload)

    {:ok, Mapper.to_map(decoded)}
  rescue
    error -> {:error, error}
  end

  defp do_decode(schema, payload) do
    decoded =
      :avro_binary_decoder.decode(
        payload,
        schema.full_name,
        schema.lookup_table,
        @decoder_options
      )

    {:ok, decoded}
  rescue
    error -> {:error, error}
  end

  defp do_encode(schema, payload) do
    encoded =
      schema.lookup_table
      |> :avro_binary_encoder.encode(schema.full_name, payload)
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
    with {:ok, schema} <- Schema.to_erlavro(schema) do
      encoded =
        schema
        |> :avro_ocf.make_header()
        |> :avro_ocf.make_ocf(List.wrap(payload))
        |> :erlang.list_to_binary()

      {:ok, encoded}
    end
  rescue
    error -> {:error, error}
  end
end
