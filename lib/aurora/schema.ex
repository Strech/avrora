defmodule Avrora.Schema do
  @moduledoc """
  A wrapper struct around AvroEx.Schema and Confluent Schema Registry for more
  convinient use.
  """

  defstruct [:id, :version, :ex_schema, :raw_schema]

  @type t :: %__MODULE__{
          id: nil | integer(),
          version: nil | integer(),
          ex_schema: AvroEx.Schema.t(),
          raw_schema: map()
        }

  @doc """
  Parses a json payload and converts it to the schema with id, AvroEx representation
  and Map representation.

  ## Examples

      iex> json = ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
      iex> {:ok, avro} = Avrora.Schema.parse(json)
      iex> avro.ex_schema.schema.qualified_names
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
      iex> avro.ex_schema.schema.qualified_names
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
          version: nil,
          ex_schema: %AvroEx.Schema{schema: schema, context: context},
          raw_schema: payload
        }
      }
    end
  end

  @doc """
  Parse the given string and extract only the subject part from it. The format is
  `subject:version`.

  ## Examples

      iex> Avrora.Schema.parse_subject("Payment")
      "Payment"
      iex> Avrora.Schema.parse_subject("io.confluent.Payment")
      "io.confluent.Payment"
  """
  @spec parse_subject(String.t()) :: String.t()
  def parse_subject(payload) when is_binary(payload) do
    payload |> String.split(":", parts: 2) |> Enum.at(0)
  end

  @doc """
  Parse the given string and extract only the version part from it. The format is
  `subject:version`.

  ## Examples

      iex> Avrora.Schema.parse_version("Payment")
      nil
      iex> Avrora.Schema.parse_version("io.confluent.Payment:42")
      42
  """
  @spec parse_version(String.t()) :: nil | integer()
  def parse_version(payload) when is_binary(payload) do
    case payload |> String.split(":", parts: 2) |> Enum.at(1) do
      nil ->
        nil

      version ->
        case Integer.parse(version) do
          {version, _} -> version
          _ -> nil
        end
    end
  end
end
