defmodule Avrora.Schema do
  @moduledoc """
  A wrapper struct around AvroEx.Schema and Confluent Schema Registry for more
  convinient use.
  """

  defstruct [:id, :version, :schema, :full_name, :lookup_table, :raw_schema]

  @type t :: %__MODULE__{
          id: nil | integer(),
          version: nil | integer(),
          # FIXME: Deprecate field `schema` in favour of `schema_store`
          schema: :avro.record_type(),
          full_name: String.t(),
          lookup_table: reference(),
          # FIXME: Rename field `raw_schema` to `json`
          raw_schema: String.t()
        }

  @doc """
  Parses a json payload and converts it to the schema with id, erlavro formar
  and raw json format.

  ## Examples

      iex> json = ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
      iex> {:ok, avro} = Avrora.Schema.parse(json)
      iex> {_, _, _, _, _, _, full_name, _} = avro.schema
      iex> full_name
      "io.confluent.Payment"
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, term()}
  def parse(payload) when is_binary(payload) do
    with {:ok, schema} <- do_parse(payload),
         {_, _, _, _, _, _, full_name, _} <- schema,
         lookup_table <- :avro_schema_store.new(),
         lookup_table <- :avro_schema_store.add_type(schema, lookup_table) do
      {
        :ok,
        %__MODULE__{
          id: nil,
          version: nil,
          schema: schema,
          full_name: full_name,
          lookup_table: lookup_table,
          raw_schema: payload
        }
      }
    end
  end

  defp do_parse(payload) do
    {:ok, :avro_json_decoder.decode_schema(payload)}
  rescue
    error in ArgumentError -> {:error, error.message}
    error in ErlangError -> {:error, error.original}
  end
end
