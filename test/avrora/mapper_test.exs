defmodule Avrora.MapperTest do
  use ExUnit.Case, async: true
  doctest Avrora.Mapper

  alias Avrora.Mapper

  describe "to_map/1" do
    test "when a complex structure is given with many primitive types" do
      transformed = Mapper.to_map(tuples())
      assert %{"a" => 1, "b" => [%{"c" => "3"}, %{"d" => nil}], "x" => %{"y" => []}} = transformed
    end
  end

  defp tuples do
    [
      {"a", 1},
      {"b", [[{"c", "3"}], [{"d", nil}]]},
      {"x", [{"y", []}]}
    ]
  end
end
