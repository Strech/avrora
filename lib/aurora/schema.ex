defmodule Avrora.Schema do
  @moduledoc """
  A wrapper struct around AvroEx.Schema and Confluent Schema Registry for more
  convinient use.
  """

  defstruct [:id, :schema, :raw_schema]

  @type t :: %__MODULE__{
          id: nil | integer(),
          schema: AvroEx.Schema.t(),
          raw_schema: map()
        }

  @doc """
  Parses a json payload and converts it to the schema with id, AvroEx representation
  and Map representation.

  ## Examples

      iex> json = ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
      iex> {:ok, avro} = Avrora.Schema.parse(json)
      iex> avro.schema.schema.qualified_names
      ["io.confluent.Payment"]
      iex> Map.get(avro.raw_schema, "name")
      "Payment"
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, term()}
  def parse(payload) when is_binary(payload) do
    with {:ok, raw_schema} <- Jason.decode(payload), do: parse(raw_schema)
  end

  @doc """
  Parses a Map payload and converts it to the schema with id, AvroEx representation
  and Map representation.

  ## Examples

      iex> payload = %{"namespace" => "io.confluent", "type" => "record", "name" => "Payment", "fields" => [%{"name" => "id", "type" => "string"}, %{"name" => "amount", "type" => "double"}]}
      iex> {:ok, avro} = Avrora.Schema.parse(payload)
      iex> avro.schema.schema.qualified_names
      ["io.confluent.Payment"]
      iex> Map.get(avro.raw_schema, "name")
      "Payment"
  """
  @spec parse(map()) :: {:ok, t()} | {:error, term()}
  def parse(payload) when is_map(payload) do
    with {:ok, schema} <- AvroEx.Schema.cast(payload),
         {:ok, schema} <- AvroEx.Schema.namespace(schema),
         {:ok, context} <- AvroEx.Schema.expand(schema, %AvroEx.Schema.Context{}) do
      {
        :ok,
        %__MODULE__{
          id: nil,
          schema: %AvroEx.Schema{schema: schema, context: context},
          raw_schema: payload
        }
      }
    end
  end
end
