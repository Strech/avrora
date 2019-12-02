defmodule Avrora.Schema.Declaration do
  @moduledoc """
  Extract type definitions and references from erlavro structures
  """

  @reserved_types ~w(
    null boolean int long float double bytes string record enum array map union fixed
  )

  @doc """
  Extract type defined and referenced types from erlavro structure.

  Type definition aliases counted as type definitions too.

  Every "string" type considered to be a reference if it's not one of the
  Avro-reserved types, such as:

  - int            - null            - enum
  - long           - boolean         - array
  - float          - string          - map
  - double         - record          - union
  - bytes          - fixed

  ## Examples

      iex> json_schema = File.read!("test/fixtures/schemas/io/confluent/Account.avsc")
      iex> erlavro = :avro_json_decoder.decode_schema(json_schema, allow_bad_references: true)
      iex> Avrora.Schema.Declaration.extract(erlavro)
      {:ok,
        %{defined: ["io.confluent.Profile", "io.confluent.Account", "io.confluent.Value"],
          referenced: ["io.confluent.PaymentHistory", "io.confluent.Messenger", "io.confluent.Email"]}
      }
  """
  @spec extract(term()) ::
          {:ok, %{defined: list(String.t()), referenced: list(String.t())}}
          | {:error, term()}
  def extract(schema) do
    definition =
      schema
      |> extract([])
      |> List.foldl(%{referenced: [], defined: []}, fn {type, name}, memo ->
        Map.update(memo, type, [name], &[name | &1])
      end)
      |> Map.new(fn {key, value} -> {key, Enum.uniq(value)} end)

    {:ok, definition}
  catch
    reason -> {:error, reason}
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
  defp extract({:avro_record_field, _, _, type, _, _, _}, state), do: extract(type, state)
  defp extract({:avro_map_type, type, _}, state), do: extract(type, state)
  defp extract({:avro_enum_type, _, _, _, _, _, _, _}, state), do: state
  defp extract({:avro_fixed_type, _, _, _, _, _, _}, state), do: state
  defp extract({:avro_primitive_type, _, _}, state), do: state

  defp extract(type, state) when is_binary(type) and type in @reserved_types, do: state
  defp extract(type, state) when is_binary(type), do: [{:referenced, type} | state]

  defp extract(type, _state), do: throw({:unknown_type, type})
end
