defmodule Avrora.TransformerTest do
  use ExUnit.Case, async: true
  doctest Avrora.Transformer

  alias Avrora.Transformer

  describe "to_tuple/1" do
    test "when a complex structure is given with many primitive types" do
      transformed = Transformer.to_tuple(%{"a" => 1, b: [%{c: "3"}, %{"d" => nil}]})
      assert [{"a", 1}, {"b", [[{"c", "3"}], [{"d", nil}]]}] = transformed
    end
  end

  describe "to_map/1" do
    test "when a complex structure is given with many primitive types" do
      transformed = Transformer.to_map([{"a", 1}, {"b", [[{"c", "3"}], [{"d", nil}]]}])
      assert %{"a" => 1, "b" => [%{"c" => "3"}, %{"d" => nil}]} = transformed
    end
  end
end
