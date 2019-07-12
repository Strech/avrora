defmodule Avrora.Transformer do
  @moduledoc """
  This module is used mainly to cover difference between common Elixir structures
  and erlavro used structures.
  """

  @doc """
  Transforming given map-based structure tructure to the tuple based.

  ## Examples

      iex> Avrora.Transformer.to_tuple(%{"a" => 1, "b" => [nil, 11.1, "three"], "c" => %{"hello" => "world"}})
      iex> |> Enum.sort_by(fn {key, _} -> key end)
      [{"a", 1}, {"b", [nil, 11.1, "three"]}, {"c", [{"hello", "world"}]}]
  """
  @spec to_tuple(term()) :: term()
  def to_tuple(value) when is_map(value) do
    Enum.reduce(value, [], fn {k, v}, memo ->
      [{to_tuple(k), to_tuple(v)} | memo]
    end)
  end

  def to_tuple(value) when is_list(value), do: Enum.map(value, &to_tuple/1)
  def to_tuple(value) when is_binary(value), do: value
  def to_tuple(value) when is_boolean(value), do: value
  def to_tuple(value) when is_nil(value), do: value
  def to_tuple(value) when is_number(value), do: value
  def to_tuple(value) when is_atom(value), do: Atom.to_string(value)

  @doc """
  Transforming given tuple-based structure tructure to the map.

  ## Examples

      iex> Avrora.Transformer.to_map([{:a, 1}, {"b", [nil, 11.1, "three"]}, {:c, [{:hello, "world"}]}])
      iex> |> Enum.sort_by(fn {key, _} -> key end) |> Map.new
      %{"a" => 1, "b" => [nil, 11.1, "three"], "c" => %{"hello" => "world"}}
  """
  @spec to_map(term()) :: term()
  def to_map(value) when is_list(value) do
    case value do
      [{_, _} | _] -> Map.new(value, fn {k, v} -> {to_map(k), to_map(v)} end)
      _ -> Enum.map(value, &to_map/1)
    end
  end

  def to_map(value) when is_map(value), do: value
  def to_map(value) when is_binary(value), do: value
  def to_map(value) when is_boolean(value), do: value
  def to_map(value) when is_nil(value), do: value
  def to_map(value) when is_number(value), do: value
  def to_map(value) when is_atom(value), do: Atom.to_string(value)
end
