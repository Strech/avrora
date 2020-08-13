defmodule Avrora.Codec.ObjectContainerFile do
  @moduledoc """
  An Avro encoder/decoder working with an Object Container File formatted Avro messages.

  It works with a binary format, which includes a required schema inside the message.
  See more about [Object Container File](https://avro.apache.org/docs/1.8.1/spec.html#Object+Container+Files).
  """

  @behaviour Avrora.Codec
  @magic_bytes <<"Obj", 1>>
  @meta_schema_key "avro.schema"

  require Logger
  alias Avrora.{Codec, Mapper, Schema}

  @impl true
  def decodable?(payload) when is_binary(payload) do
    case payload do
      <<@magic_bytes, _::binary>> -> true
      _ -> false
    end
  end

  @impl true
  def extract_schema(payload) when is_binary(payload) do
    with {:ok, {headers, erlavro, _}} <- do_decode(payload),
         {:ok, json} <- extract_json_schema(headers) do
      Schema.from_erlavro(erlavro, json: json)
    end
  end

  @impl true
  def decode(payload, opts \\ []) when is_binary(payload) do
    unless is_nil(Keyword.get(opts, :schema)) do
      Logger.warn("message already contains embeded schema, given schema will be ignored")
    end

    with {:ok, {_, _, decoded}} <- do_decode(payload), do: {:ok, Mapper.to_map(decoded)}
  end

  @impl true
  def encode(payload, schema: schema) when is_map(payload) do
    with {:ok, body} <- Codec.Plain.encode(payload, schema: schema),
         {:ok, schema} <- Schema.to_erlavro(schema) do
      do_encode(body, schema)
    end
  end

  defp do_decode(payload) do
    {:ok, :avro_ocf.decode_binary(payload)}
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
end
