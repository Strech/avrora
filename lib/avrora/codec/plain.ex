defmodule Avrora.Codec.Plain do
  @moduledoc """
  An Avro encoder/decoder working with a plain Avro messages.

  It works with a binary format, which doesn't include any schema inside
  like Object Container File or the magic bytes for a Schema Registry.
  """

  @behaviour Avrora.Codec

  alias Avrora.AvroDecoderOptions
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
  def encode(payload, schema: schema) do
    with {:ok, schema} <- resolve(schema), do: do_encode(payload, schema)
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
        AvroDecoderOptions.options()
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
      |> List.wrap()
      |> :erlang.list_to_binary()

    {:ok, encoded}
  rescue
    error -> {:error, error}
  end
end
