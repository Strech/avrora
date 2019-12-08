defmodule Avrora.Schema do
  @moduledoc """
  Convenience wrapper struct for `AvroEx.Schema` and Confluent Schema Registry.
  """

  alias Avrora.Schema.ReferenceCollector

  defstruct [:id, :version, :full_name, :lookup_table, :json]

  @type t :: %__MODULE__{
          id: nil | integer(),
          version: nil | integer(),
          full_name: String.t(),
          lookup_table: reference(),
          json: String.t()
        }

  @type reference_lookup_fun :: (String.t() -> {:ok, String.t()} | {:error, term()})
  @default_reference_lookup &__MODULE__.reference_lookup/1

  @doc """
  Parse Avro schema JSON and convert to struct.

  ## Examples

      iex> json = ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
      iex> {:ok, schema} = Avrora.Schema.parse(json)
      iex> schema.full_name
      "io.confluent.Payment"
  """
  @spec parse(String.t(), reference_lookup_fun) :: {:ok, t()} | {:error, term()}
  def parse(payload, reference_lookup \\ @default_reference_lookup) when is_binary(payload) do
    with {:ok, [schema | _] = schemas} <- parse_recursive(payload, reference_lookup),
         {_, _, _, _, _, _, full_name, _} <- schema,
         lookup_table <- :avro_schema_store.new(),
         :ok <- Enum.each(schemas, &:avro_schema_store.add_type(&1, lookup_table)),
         {:ok, schema} <- do_compile(full_name, lookup_table) do
      {
        :ok,
        %__MODULE__{
          id: nil,
          version: nil,
          full_name: full_name,
          lookup_table: lookup_table,
          json: :avro_json_encoder.encode_type(schema)
        }
      }
    end
  end

  @doc """
  An example of a reference lookup which returns empty JSON body
  """
  @spec reference_lookup(String.t()) :: {:ok, String.t()} | {:error, term()}
  def reference_lookup(_), do: {:ok, ~s({})}

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
    do: do_compile(schema.full_name, schema.lookup_table)

  defp parse_recursive(payload, reference_lookup) do
    with {:ok, schema} <- do_parse(payload),
         {:ok, references} <- ReferenceCollector.collect(schema),
         payloads <-
           Enum.map(references, fn reference ->
             case reference_lookup.(reference) do
               {:ok, payload} -> payload
               {:error, error} -> throw(error)
             end
           end),
         schemas <-
           Enum.map(payloads, fn payload ->
             case do_parse(payload) do
               {:ok, schema} -> schema
               {:error, error} -> throw(error)
             end
           end) do
      {:ok, [schema | schemas]}
    end
  catch
    error -> {:error, error}
  end

  defp parse_recursive_2(payload, reference_lookup) do
    with {:ok, schema} <- do_parse(payload),
         {:ok, references} <- ReferenceCollector.collect(schema),
         payloads <- Enum.map(references, &reference_lookup.(&1)),
         :ok <- Enum.find(payloads, :ok, &(elem(&1, 0) == :error)),
         schemas <- Enum.map(payloads, &do_parse(elem(&1, 1))),
         :ok <- Enum.find(schemas, :ok, &(elem(&1, 0) == :error)) do
      {:ok, [schema | Enum.map(schemas, &elem(&1, 1))]}
    end
  end

  # Compile complete version of the `erlavro` format with all references
  # being resolved, converting errors to error return
  defp do_compile(full_name, lookup_table) do
    {:ok, :avro_util.expand_type(full_name, lookup_table)}
  rescue
    _ in MatchError -> {:error, :bad_reference}
    error in ErlangError -> {:error, error.original}
  end

  # Parse schema to `erlavro` format, converting errors to error return
  defp do_parse(payload) do
    {:ok, :avro_json_decoder.decode_schema(payload, allow_bad_references: true)}
  rescue
    error in ArgumentError -> {:error, error.message}
    error in ErlangError -> {:error, error.original}
  end
end
