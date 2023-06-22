defmodule Avrora.Codec.ObjectContainerFile do
  @dialyzer {:no_opaque, [extract_json_schema: 1, extract_schema: 1]}

  @moduledoc """
  An Avro encoder/decoder working with an Object Container File formatted Avro messages.

  It works with a binary format, which includes a required schema inside the message.
  See more about [Object Container File](https://avro.apache.org/docs/1.8.1/spec.html#Object+Container+Files).
  """

  @behaviour Avrora.Codec
  @magic_bytes <<"Obj", 1>>
  @meta_schema_key "avro.schema"

  require Logger
  alias Avrora.AvroDecoderOptions
  alias Avrora.Codec
  alias Avrora.Config
  alias Avrora.Resolver
  alias Avrora.Schema.Encoder, as: SchemaEncoder

  @impl true
  def is_decodable(payload) when is_binary(payload) do
    case payload do
      <<@magic_bytes, _::binary>> -> true
      _ -> false
    end
  end

  @impl true
  def extract_schema(payload) when is_binary(payload) do
    with {:ok, {headers, {_, _, _, _, _, _, full_name, _} = erlavro, _}} <- do_decode(payload),
         {:ok, nil} <- memory_storage().get(full_name),
         {:ok, json} <- extract_json_schema(headers),
         {:ok, schema} <- SchemaEncoder.from_erlavro(erlavro, json: json) do
      memory_storage().put(full_name, schema)
    end
  end

  @impl true
  def decode(payload) when is_binary(payload) do
    with {:ok, {_, _, decoded}} <- do_decode(payload), do: {:ok, decoded}
  end

  @impl true
  def decode(payload, schema: _schema) when is_binary(payload) do
    Logger.warning("message already contains embeded schema, given schema will be ignored")
    decode(payload)
  end

  @impl true
  def encode(payload, schema: schema) when is_binary(payload) or is_map(payload) do
    with {:ok, schema} <- resolve(schema),
         {:ok, body} <- Codec.Plain.encode(payload, schema: schema),
         {:ok, schema} <- SchemaEncoder.to_erlavro(schema) do
      do_encode(body, schema)
    end
  end

  defp resolve(schema) do
    cond do
      is_binary(schema.full_name) && is_reference(schema.lookup_table) -> {:ok, schema}
      is_binary(schema.full_name) -> Resolver.resolve(schema.full_name)
      true -> {:error, :unusable_schema}
    end
  end

  defp do_decode(payload) do
    {:ok, :avro_ocf.decode_binary(payload, AvroDecoderOptions.options())}
  rescue
    MatchError -> {:error, :schema_mismatch}
    error -> {:error, error}
  end

  defp do_encode(payload, schema) do
    encoded =
      schema
      |> :avro_ocf.make_header()
      |> :avro_ocf.make_ocf(List.wrap(payload))
      |> :erlang.list_to_binary()

    {:ok, encoded}
  rescue
    error -> {:error, error}
  end

  defp extract_json_schema(headers) do
    with {_, _, meta, _} <- headers,
         {@meta_schema_key, json} <- Enum.find(meta, fn {key, _} -> key == @meta_schema_key end) do
      {:ok, json}
    end
  end

  defp memory_storage, do: Config.self().memory_storage()
end
