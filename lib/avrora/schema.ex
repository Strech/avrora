defmodule Avrora.Schema do
  @moduledoc """
  Convenience wrapper struct for erlavro records.
  """

  alias Avrora.Config
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
  @reference_lookup_fun &__MODULE__.reference_lookup/1

  @doc """
  Parse Avro schema JSON and convert to struct.

  ## Examples

      iex> json = ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
      iex> {:ok, schema} = Avrora.Schema.parse(json)
      iex> schema.full_name
      "io.confluent.Payment"
  """
  @spec parse(String.t(), reference_lookup_fun) :: {:ok, t()} | {:error, term()}
  def parse(payload, reference_lookup_fun \\ @reference_lookup_fun) when is_binary(payload) do
    lookup_table = ets().new()

    with {:ok, [schema | _]} <- parse_recursive(payload, lookup_table, reference_lookup_fun),
         {_, _, _, _, _, _, full_name, _} <- schema,
         {:ok, schema} <- do_compile(full_name, lookup_table) do
      {
        :ok,
        %__MODULE__{
          id: nil,
          version: nil,
          full_name: full_name,
          lookup_table: lookup_table,
          json: to_json(schema)
        }
      }
    else
      {:error, reason} ->
        true = :ets.delete(lookup_table)
        {:error, reason}
    end
  end

  @doc """
  Check that schema can be used for encoding/decoding

  ## Examples

      iex> Avrora.Schema.usable?(%Avrora.Schema{})
      false
      iex> table = Avrora.Config.self().ets_lib().new()
      iex> Avrora.Schema.usable?(%Avrora.Schema{full_name: "io.confluent", lookup_table: table})
      true
  """
  @spec usable?(t()) :: boolean()
  def usable?(%__MODULE__{} = schema),
    do: is_binary(schema.full_name) && is_reference(schema.lookup_table)

  @doc """
  An example of a reference lookup which returns empty JSON body
  """
  @spec reference_lookup(String.t()) :: {:ok, String.t()} | {:error, term()}
  def reference_lookup(_), do: {:ok, ~s({})}

  @doc """
  Convert `erlavro` format to the struct.

  ## Examples

      iex> payload =
      ...>   {:avro_record_type, "Payment", "io.confluent", "", [],
      ...>        [
      ...>          {:avro_record_field, "id", "", {:avro_primitive_type, "string", []}, :undefined,
      ...>           :ascending, []},
      ...>          {:avro_record_field, "amount", "", {:avro_primitive_type, "double", []}, :undefined,
      ...>           :ascending, []}
      ...>        ], "io.confluent.Payment", []}
      iex> {:ok, schema} = Avrora.Schema.from_erlavro(payload)
      iex> schema.id
      nil
      iex> schema.full_name
      "io.confluent.Payment"
  """
  @spec from_erlavro(term(), keyword()) :: {:ok, t()} | {:error, term()}
  def from_erlavro(schema, attributes \\ []) do
    lookup_table = ets().new()

    with {_, _, _, _, _, _, full_name, _} <- schema,
         lookup_table <- :avro_schema_store.add_type(schema, lookup_table),
         json <- Keyword.get_lazy(attributes, :json, fn -> to_json(schema) end) do
      {
        :ok,
        %__MODULE__{
          id: nil,
          version: nil,
          full_name: full_name,
          lookup_table: lookup_table,
          json: json
        }
      }
    else
      {:error, reason} ->
        true = :ets.delete(lookup_table)
        {:error, reason}
    end
  end

  @doc """
  Convert struct to `erlavro` format and look it up in `avro_schema_store`.

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

  defp to_json(schema), do: :avro_json_encoder.encode_type(schema)

  defp parse_recursive(payload, lookup_table, reference_lookup_fun) do
    with {:ok, schema} <- do_parse(payload),
         {:ok, references} <- ReferenceCollector.collect(schema),
         lookup_table <- :avro_schema_store.add_type(schema, lookup_table) do
      payloads =
        references
        |> Enum.reject(&:avro_schema_store.lookup_type(&1, lookup_table))
        |> Enum.map(fn reference ->
          reference |> reference_lookup_fun.() |> unwrap!()
        end)

      schemas =
        Enum.flat_map(payloads, fn payload ->
          payload |> parse_recursive(lookup_table, reference_lookup_fun) |> unwrap!()
        end)

      {:ok, [schema | schemas]}
    end
  catch
    error -> {:error, error}
  end

  defp unwrap!({:ok, result}), do: result
  defp unwrap!({:error, error}), do: throw(error)

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

  defp ets, do: Config.self().ets_lib()
end
