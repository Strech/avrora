defmodule Avrora.Schema do
  @moduledoc """
  A wrapper struct around AvroEx.Schema and Confluent Schema Registry for more
  convinient use.
  """

  defstruct [:id, :version, :schema, :raw_schema]

  @type t :: %__MODULE__{
          id: nil | integer(),
          version: nil | integer(),
          schema: keyword(),
          raw_schema: String.t()
        }

  @doc """
  Parses a json payload and converts it to the schema with id, erlavro formar
  and raw json format.

  ## Examples

      iex> json = ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
      iex> {:ok, avro} = Avrora.Schema.parse(json)
      iex> {type, _, _, _, _, full_name, _} = avro.schema
      iex> full_name <> " of " <> type
      "io.confluent.Payment of :avro_record_type"
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, term()}
  def parse(payload) when is_binary(payload) do
    with {:ok, schema} <- do_decode(payload) do
      {
        :ok,
        %__MODULE__{
          id: nil,
          version: nil,
          schema: schema,
          raw_schema: payload
        }
      }
    end
  end

  defp do_decode(payload) do
    try do
      {:ok, :avro_json_decoder.decode_schema(payload)}
    rescue
      error in ArgumentError -> {:error, error.message}
      error in ErlangError -> {:error, error.original}
    end
  end
end
