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
  @spec from_json(String.t(), name: String.t(), reference_lookup_fun: reference_lookup_fun) ::
          {:ok, Schema.t()} | {:error, term()}
  def from_json(definition, options \\ []) do
    lookup_table = ets().new()
    name = Keyword.get(options, :name)
    reference_lookup_fun = Keyword.get(options, :reference_lookup_fun, @reference_lookup_fun)

    with {:ok, full_name} <- add_recursively(definition, name, lookup_table, reference_lookup_fun),
         {:ok, erlavro} <- do_compile(full_name, lookup_table) do
      # It could be that json field will be moved to be a method because of
      # schema registry support of references. OR we should care about how
      # to calculate it
      {
        :ok,
        %Schema{
          id: nil,
          version: nil,
          full_name: full_name,
          lookup_table: lookup_table,
          json: to_json(erlavro)
        }
      }
    else
      {:error, reason} ->
        true = :ets.delete(lookup_table)
        {:error, reason}
    end
  end

  defp add_recursively(definition, name, lookup_table, reference_lookup_fun) do
    with {:ok, erlavro} <- do_parse(definition),
         {:ok, references} <- ReferenceCollector.collect(erlavro),
         {:ok, full_name} <- add_type(name, erlavro, lookup_table) do
      references
      |> Enum.reject(&:avro_schema_store.lookup_type(&1, lookup_table))
      |> Enum.each(fn reference ->
        reference_lookup_fun.(reference)
        |> unwrap!()
        |> add_recursively(reference, lookup_table, reference_lookup_fun)
        |> unwrap!()
      end)

      {:ok, full_name}
    end
  catch
    # TODO: Improve error handling
    error -> {:error, error}
  end

  defp add_type(name, erlavro, lookup_table) do
    with {:ok, full_name} <- extract_full_name(erlavro, name) do
      if :avro.is_named_type(erlavro),
        do: :avro_schema_store.add_type(erlavro, lookup_table),
        else: :avro_schema_store.add_type(full_name, erlavro, lookup_table)

      {:ok, full_name}
    end
  end

  @doc """
  An example of a reference lookup which returns empty JSON body
  """
  @spec reference_lookup(String.t()) :: {:error, term()}
  def reference_lookup(_), do: {:error, :undefined_reference_lookup_function}

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

  defp unwrap!({:ok, result}), do: result
  defp unwrap!({:error, error}), do: throw(error)

  defp extract_full_name(erlavro, fallback \\ nil) do
    case erlavro do
      {:avro_fixed_type, _, _, _, _, full_name, _} -> {:ok, full_name}
      {:avro_enum_type, _, _, _, _, _, full_name, _} -> {:ok, full_name}
      {:avro_record_type, _, _, _, _, _, full_name, _} -> {:ok, full_name}
      _ -> if is_nil(fallback), do: {:error, :unnamed_type}, else: {:ok, fallback}
    end
  end

  # TODO: Rename to do_expand because it makes more sense
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
