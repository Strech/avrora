defmodule Avrora.Mapper do
  @moduledoc """
  Functions to convert between common Elixir structures and erlavro structures.
  """

  @doc """
  Convert tuple-based structure returned by erlavro to Elixir map.

  ## Examples

      iex> map = Avrora.Mapper.to_map([{:a, 1}, {"b", [nil, 11.1, "three"]}, {:c, [{:hello, "world"}]}])
      iex> %{"a" => a, "b" => b, "c" => c} = map
      iex> a
      1
      iex> b
      [nil, 11.1, "three"]
      iex> c
      %{"hello" => "world"}
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
