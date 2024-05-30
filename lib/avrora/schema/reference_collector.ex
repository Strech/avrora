defmodule Avrora.Schema.ReferenceCollector do
  @moduledoc """
  Collect non local type references from `erlavro` structures.
  """

  @builtin_types ~w(
    null boolean int long float double bytes string record enum array map union fixed
  )

  @doc """
  Collect non local type referenced types from `erlavro` structure.

  Type definition aliases counted as type definitions too.

  Every json-string type value considered to be a reference
  if it's not one of the reserved by Avro Specification types, such as:

  - int            - null            - enum
  - long           - boolean         - array
  - float          - string          - map
  - double         - record          - union
  - bytes          - fixed

  ## Examples

      iex> json_schema = File.read!("test/fixtures/schemas/io/acme/Account.avsc")
      iex> erlavro = :avro_json_decoder.decode_schema(json_schema, allow_bad_references: true)
      iex> Avrora.Schema.ReferenceCollector.collect(erlavro)
      {:ok, ["io.acme.Email", "io.acme.Messenger", "io.acme.PaymentHistory"]}
  """
  @spec collect(term()) :: {:ok, list(String.t())} | {:error, term()}
  def collect(schema) do
    collected =
      schema
      |> do_collect()
      |> List.foldl(%{ref: [], def: []}, fn {type, name}, memo ->
        Map.update(memo, type, [name], &[name | &1])
      end)

    {:ok, Enum.uniq(collected.ref) -- Enum.uniq(collected.def)}
  catch
    reason -> {:error, reason}
  end

  defp do_collect({:avro_record_type, _, namespace, _, aliases, fields, fullname, _}) do
    aliases =
      aliases
      |> :avro_util.canonicalize_aliases(namespace)
      |> Enum.map(&{:def, &1})

    List.foldl(fields, [{:def, fullname} | aliases], fn type, memo ->
      memo ++ do_collect(type)
    end)
  end

  defp do_collect({:avro_union_type, _, _} = type) do
    type
    |> :avro_union.get_types()
    |> Enum.flat_map(&do_collect/1)
  end

  defp do_collect({:avro_array_type, type, _}), do: do_collect(type)
  defp do_collect({:avro_record_field, _, _, type, _, _, _}), do: do_collect(type)
  defp do_collect({:avro_map_type, type, _}), do: do_collect(type)
  defp do_collect({:avro_enum_type, _, _, _, _, _, _, _}), do: []
  defp do_collect({:avro_fixed_type, _, _, _, _, _, _}), do: []
  defp do_collect({:avro_primitive_type, _, _}), do: []

  defp do_collect(type) when is_binary(type) and type in @builtin_types, do: []
  defp do_collect(type) when is_binary(type), do: [{:ref, type}]

  defp do_collect(type), do: throw({:unknown_type, type})
end
