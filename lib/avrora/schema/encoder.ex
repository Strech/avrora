defmodule Avrora.Schema.Encoder do
  @moduledoc """
  Encodes and parses Avro schemas from various formats, like JSON and erlavro into `Avrora.Schema`.
  """

  alias Avrora.Config
  alias Avrora.Schema
  alias Avrora.Schema.ReferenceCollector

  @type reference_lookup_fun :: (String.t() -> {:ok, String.t()} | {:error, term()})
  @reference_lookup_fun &__MODULE__.reference_lookup/1

  @doc """
  Parse Avro schema JSON and convert to the Schema struct.

  ## Examples

      iex> json = ~s({"namespace":"io.acme","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
      iex> {:ok, schema} = Avrora.Schema.Encoder.from_json(json)
      iex> schema.full_name
      "io.acme.Payment"
  """
  @spec from_json(String.t(), reference_lookup_fun) :: {:ok, Schema.t()} | {:error, term()}
  def from_json(payload, reference_lookup_fun \\ @reference_lookup_fun) when is_binary(payload) do
    lookup_table = ets().new()

    with {:ok, [schema | _]} <- parse_recursive(payload, lookup_table, reference_lookup_fun),
         {:ok, full_name} <- extract_full_name(schema),
         {:ok, schema} <- do_compile(full_name, lookup_table) do
      {
        :ok,
        %Schema{
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
  An example of a reference lookup which returns empty JSON body
  """
  @spec reference_lookup(String.t()) :: {:ok, String.t()} | {:error, term()}
  def reference_lookup(_), do: {:ok, ~s({})}

  @doc """
  Convert `erlavro` format to the Schema struct.

  ## Examples

      iex> payload =
      ...>   {:avro_record_type, "Payment", "io.acme", "", [],
      ...>        [
      ...>          {:avro_record_field, "id", "", {:avro_primitive_type, "string", []}, :undefined,
      ...>           :ascending, []},
      ...>          {:avro_record_field, "amount", "", {:avro_primitive_type, "double", []}, :undefined,
      ...>           :ascending, []}
      ...>        ], "io.acme.Payment", []}
      iex> {:ok, schema} = Avrora.Schema.Encoder.from_erlavro(payload)
      iex> schema.id
      nil
      iex> schema.full_name
      "io.acme.Payment"
  """
  @spec from_erlavro(term(), keyword()) :: {:ok, Schema.t()} | {:error, term()}
  def from_erlavro(schema, attributes \\ []) do
    lookup_table = ets().new()

    with {:ok, full_name} <- extract_full_name(schema),
         lookup_table <- :avro_schema_store.add_type(schema, lookup_table),
         json <- Keyword.get_lazy(attributes, :json, fn -> to_json(schema) end) do
      {
        :ok,
        %Schema{
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

      iex> json = ~s({"namespace":"io.acme","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
      iex> {:ok, schema} = Avrora.Schema.Encoder.from_json(json)
      iex> {:ok, {type, _, _, _, _, _, full_name, _}} = Avrora.Schema.Encoder.to_erlavro(schema)
      iex> full_name
      "io.acme.Payment"
      iex> type
      :avro_record_type
  """
  @spec to_erlavro(Schema.t()) :: {:ok, term()} | {:error, term()}
  def to_erlavro(%Schema{} = schema),
    do: do_compile(schema.full_name, schema.lookup_table)

  defp to_json(schema), do: :avro_json_encoder.encode_type(schema)

  defp parse_recursive(payload, lookup_table, reference_lookup_fun) do
    with {:ok, schema} <- do_parse(payload),
         {:ok, _} <- extract_full_name(schema),
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

  defp extract_full_name(schema) do
    case schema do
      {:avro_fixed_type, _, _, _, _, full_name, _} -> {:ok, full_name}
      {:avro_enum_type, _, _, _, _, _, full_name, _} -> {:ok, full_name}
      {:avro_record_type, _, _, _, _, _, full_name, _} -> {:ok, full_name}
      _ -> {:error, :unnamed_type}
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

  defp ets, do: Config.self().ets_lib()
end
