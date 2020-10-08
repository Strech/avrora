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

  alias Avrora.Resolver

  @impl true
  def is_decodable(payload) when is_binary(payload), do: true

  @impl true
  def extract_schema(_payload), do: {:error, :schema_not_found}

  @impl true
  def decode(_payload), do: {:error, :schema_required}

  @impl true
  def decode(payload, schema: schema) when is_binary(payload) do
    with {:ok, schema} <- resolve(schema), do: do_decode(payload, schema)
  end

  @impl true
  def encode(payload, schema: schema) when is_map(payload) do
    with {:ok, schema} <- resolve(schema), do: do_encode(payload, schema)
  end

  @doc """
    The hook by default converts :null atom (erlang) to nil, based on it's avro type.
  """
  def __hook__(type, _sub_name_or_id, data, decode_fun) do
    case :avro.get_type_name(type) do
      "null" -> {nil, data}
      _ -> decode_fun.(data)
    end
  end

  defp resolve(schema) do
    cond do
      is_binary(schema.full_name) && is_reference(schema.lookup_table) -> {:ok, schema}
      is_binary(schema.full_name) -> Resolver.resolve(schema.full_name)
      true -> {:error, :unusable_schema}
    end
  end

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

  defp do_encode(payload, schema) do
    encoded =
      schema.lookup_table
      |> :avro_binary_encoder.encode(schema.full_name, payload)
      |> :erlang.list_to_binary()

    {:ok, encoded}
  rescue
    error -> {:error, error}
  end
end
