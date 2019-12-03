defmodule Avrora.Schema do
  @moduledoc """
  Convenience wrapper struct for `AvroEx.Schema` and Confluent Schema Registry.
  """

  alias Avrora.Schema.Declaration

  defstruct [:id, :version, :full_name, :lookup_table, :json]

  @type t :: %__MODULE__{
          id: nil | integer(),
          version: nil | integer(),
          full_name: String.t(),
          lookup_table: reference(),
          json: String.t()
        }

  @doc """
  Parse Avro schema JSON and convert to struct.

  ## Examples

      iex> json = ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
      iex> {:ok, schema} = Avrora.Schema.parse(json)
      iex> schema.full_name
      "io.confluent.Payment"
  """
  @spec parse(String.t(), keyword(term())) :: {:ok, t()} | {:error, term()}
  def parse(payload, options \\ []) when is_binary(payload) do
    callback = Keyword.get(options, :callback, fn _ -> nil end)

    with {:ok, schema} <- do_parse(payload),
         {_, _, _, _, _, _, full_name, _} <- schema,
         lookup_table <- :avro_schema_store.new(),
         lookup_table <- :avro_schema_store.add_type(schema, lookup_table) do
      {:ok, %{defined: defined, referenced: referenced}} = Declaration.extract(schema)

      Enum.each(referenced -- defined, fn name ->
        x = callback.(name)
        unless is_nil(x), do: :avro_schema_store.add_type(x, lookup_table)
      end)

      with {:ok, erlavro} <- do_expand_type(full_name, lookup_table) do
        {
          :ok,
          %__MODULE__{
            id: nil,
            version: nil,
            full_name: full_name,
            lookup_table: lookup_table,
            json: :avro_json_encoder.encode_type(erlavro)
          }
        }
      end
    end
  end

  @doc """
  Convert struct to `erlavro` format and look up in `avro_schema_store`.

  ## Examples

      iex> json = ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
      iex> {:ok, schema} = Avrora.Schema.parse(json)
      iex> {:ok, {type, _, _, _, _, _, full_name, _}} = Avrora.Schema.to_erlavro(schema)
      iex> full_name
      "io.confluent.Payment"
      iex> type
      :avro_record_type
  """
  @spec to_erlavro(t()) :: {:ok, term()} | {:error, term()}
  def to_erlavro(%__MODULE__{} = schema),
    do: do_expand_type(schema.full_name, schema.lookup_table)

  defp do_expand_type(type_name, lookup_table) do
    {:ok, :avro_util.expand_type(type_name, lookup_table)}
  rescue
    _ in MatchError -> {:error, :bad_reference}
    error in ArgumentError -> {:error, error.message}
    error in ErlangError -> {:error, error.original}
  end

  # Parse schema, converting errors to error return
  defp do_parse(payload) do
    {:ok, :avro_json_decoder.decode_schema(payload, allow_bad_references: true)}
  rescue
    error in ArgumentError -> {:error, error.message}
    error in ErlangError -> {:error, error.original}
  end
end
