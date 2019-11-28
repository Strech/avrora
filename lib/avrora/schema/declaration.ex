defmodule Avrora.Schema.Declaration do
  @moduledoc """
  TODO

  1. Cover all types with syntetic example
  2. Write tests!!!!!
  3. Think about structure we return as def/ref
  4. Naming: %__MODULE__{defined: [], referenced: []}
  """

  # schema = :avro_json_decoder.decode_schema(File.read!("test/fixtures/schemas/io/confluent/Account.avsc"), allow_bad_references: true)
  # Avrora.Schema.Definition.extract(schema)

  @reserved_types ~w(null boolean int long float double bytes string record enum array map union fixed)

  def extract(schema) do
    definition =
      schema
      |> extract([])
      |> List.foldl(%{referenced: [], defined: []}, fn {type, name}, memo ->
        Map.update(memo, type, [name], &[name | &1])
      end)
      |> Map.new(fn {key, value} -> {key, Enum.uniq(value)} end)

    IO.puts("---------- ---------- References  ---------- ----------")
    IO.puts(Enum.join(definition.referenced, "\n"))

    IO.puts("---------- ---------- Definitions ---------- ----------")
    IO.puts(Enum.join(definition.defined, "\n"))

    IO.puts("---------- ---------- ---------- ---------- -----------")

    {:ok, definition}
  end

  defp extract({:avro_record_type, _, namespace, _, aliases, fields, fullname, _}, state) do
    IO.puts("Record <#{fullname}>")

    aliases =
      aliases
      |> :avro_util.canonicalize_aliases(namespace)
      |> Enum.map(&{:defined, &1})

    List.foldl(fields, [{:defined, fullname} | aliases] ++ state, fn type, state ->
      extract(type, state)
    end)
  end

  defp extract({:avro_record_field, name, _, type, _, _, _}, state) do
    IO.puts("Record.field {#{name}}")
    extract(type, state)
  end

  defp extract({:avro_enum_type, _, _, _, _, _, _, _}, state) do
    IO.puts("Enum")
    state
  end

  defp extract({:avro_array_type, type, _}, state) do
    IO.puts("Array")

    if is_binary(type) do
      IO.puts("Reference <#{type}>")

      [{:referenced, type} | state]
    else
      extract(type, state)
    end
  end

  defp extract({:avro_map_type, type, _}, state) do
    IO.puts("Map")

    extract(type, state)
  end

  defp extract({:avro_union_type, _, _} = type, state) do
    IO.puts("Union")

    type
    |> :avro_union.get_types()
    |> List.foldl(state, fn utype, memo -> memo ++ extract(utype, state) end)
  end

  defp extract({:avro_fixed_type, _, _, _aliases, _, fullname, _}, state) do
    IO.puts("Fixed <#{fullname}>")
    state
  end

  defp extract({:avro_primitive_type, _, _}, state) do
    IO.puts("Primitive")
    state
  end

  defp extract(type, state) when is_binary(type) do
    if Enum.member?(@reserved_types, type) do
      IO.puts("Primitive/Complex (reserved)")
      state
    else
      IO.puts("Reference <#{type}>")
      [{:referenced, type} | state]
    end
  end

  defp extract(type, _state), do: raise("unexpected type `#{type}`, this should never happen")
end
