defmodule Avrora.Schema.Definition do
  @moduledoc """
  TODO
  """

  # schema = :avro_json_decoder.decode_schema(File.read!("test/fixtures/schemas/io/confluent/Account.avsc"), allow_bad_references: true)
  # Avrora.Schema.Definition.extract(schema)

  def extract(schema) do
    definition =
      schema
      |> extract([])
      |> List.foldl(%{ref: [], def: []}, fn {type, name}, memo ->
        Map.update(memo, type, [name], &[name | &1])
      end)
      |> Map.new(fn {key, value} -> {key, Enum.uniq(value)} end)

    IO.puts("---------- ---------- References  ---------- ----------")
    IO.puts(Enum.join(definition.ref, "\n"))

    IO.puts("---------- ---------- Definitions ---------- ----------")
    IO.puts(Enum.join(definition.def, "\n"))

    IO.puts("---------- ---------- ---------- ---------- -----------")

    {:ok, definition}
  end

  defp extract({:avro_record_type, _, namespace, _, aliases, fields, fullname, _}, state) do
    IO.puts("Record <#{fullname}>")

    aliases =
      aliases
      |> :avro_util.canonicalize_aliases(namespace)
      |> Enum.map(&{:def, &1})

    List.foldl(fields, [{:def, fullname} | aliases] ++ state, fn type, state ->
      extract(type, state)
    end)
  end

  defp extract({:avro_record_field, name, _, type, _, _, _aliases}, state) do
    IO.puts("Record.field {#{name}}")
    extract(type, state)
  end

  defp extract({:avro_enum_type, _, _, _aliases, _, _symbols, _fullname, _}, state) do
    IO.puts("Enum")
    state
  end

  defp extract({:avro_array_type, type, _}, state) do
    IO.puts("Array")

    if is_binary(type) do
      IO.puts("Reference <#{type}>")

      [{:ref, type} | state]
    else
      extract(type, state)
    end
  end

  defp extract({:avro_map_type, _type, _}, state) do
    IO.puts("Map")
    state
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
    IO.puts("Reference <#{type}>")
    [{:ref, type} | state]
  end

  defp extract(type, state) do
    IO.puts("Unknown")
    IO.puts("^^^^^^^ #{inspect(type)}")
    state
  end
end
