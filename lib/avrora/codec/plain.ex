defmodule Avrora.Codec.Plain do
  @moduledoc """
  An Avro encoder/decoder working with a plain Avro messages.

  It works with a binary format, which doesn't include any schema inside
  like Object Container File or the magic bytes for a Schema Registry.
  """

  @behaviour Avrora.Codec
  @decoder_options %{
    encoding: :avro_binary,
    hook: &__MODULE__.__hook__/4,
    is_wrapped: true,
    map_type: :proplist,
    record_type: :map
  }

  alias Avrora.{Resolver, Schema}

  @impl true
  def decodable?(payload) when is_binary(payload), do: true

  @impl true
  def extract_schema(_payload), do: {:error, :schema_not_found}

  @impl true
  def decode(_payload), do: {:error, :schema_required}

  @impl true
  def decode(payload, schema: schema) when is_binary(payload) do
    cond do
      Schema.usable?(schema) ->
        do_decode(payload, schema)

      is_binary(schema.full_name) ->
        with {:ok, schema} <- Resolver.resolve(schema.full_name),
             do: do_decode(payload, schema)

      true ->
        {:error, :unusable_schema}
    end
  end

  @impl true
  def encode(payload, schema: schema) when is_map(payload) do
    encoded =
      schema.lookup_table
      |> :avro_binary_encoder.encode(schema.full_name, payload)
      |> :erlang.list_to_binary()

    {:ok, encoded}
  rescue
    error -> {:error, error}
  end

  # NOTE: `erlavro` supports setting a decoder hook, but we don't, at least for now
  @doc false
  def __hook__(_type, _sub_name_or_id, data, decode_fun), do: decode_fun.(data)

  defp do_decode(payload, schema) do
    decoded =
      :avro_binary_decoder.decode(
        payload,
        schema.full_name,
        schema.lookup_table,
        @decoder_options
      )

    {:ok, decoded}
  rescue
    MatchError -> {:error, :schema_mismatch}
    error -> {:error, error}
  end
end
