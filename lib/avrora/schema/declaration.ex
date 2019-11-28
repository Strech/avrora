defmodule Avrora.Schema.Declaration do
  @moduledoc """
  TODO
  """

  @reserved_types ~w(
    null boolean int long float double bytes string record enum array map union fixed
  )

  def extract(schema) do
    definition =
      schema
      |> extract([])
      |> List.foldl(%{referenced: [], defined: []}, fn {type, name}, memo ->
        Map.update(memo, type, [name], &[name | &1])
      end)
      |> Map.new(fn {key, value} -> {key, Enum.uniq(value)} end)

    {:ok, definition}
  end

  defp extract({:avro_record_type, _, namespace, _, aliases, fields, fullname, _}, state) do
    aliases =
      aliases
      |> :avro_util.canonicalize_aliases(namespace)
      |> Enum.map(&{:defined, &1})

    List.foldl(fields, [{:defined, fullname} | aliases] ++ state, fn type, state ->
      extract(type, state)
    end)
  end

  defp extract({:avro_union_type, _, _} = type, state) do
    type
    |> :avro_union.get_types()
    |> List.foldl(state, fn typ, memo -> memo ++ extract(typ, state) end)
  end

  defp extract({:avro_array_type, type, _}, state), do: extract(type, state)
  defp extract({:avro_record_field, name, _, type, _, _, _}, state), do: extract(type, state)
  defp extract({:avro_map_type, type, _}, state), do: extract(type, state)
  defp extract({:avro_enum_type, _, _, _, _, _, _, _}, state), do: state
  defp extract({:avro_fixed_type, _, _, _, _, _, _}, state), do: state
  defp extract({:avro_primitive_type, _, _}, state), do: state

  defp extract(type, state) when is_binary(type) and type in @reserved_types, do: state
  defp extract(type, state) when is_binary(type), do: [{:referenced, type} | state]
  defp extract(type, _state), do: raise("unexpected type `#{type}`, this should never happen")
end
