defmodule Avrora.Schema.NameTest do
  use ExUnit.Case, async: true
  doctest Avrora.Schema.Name

  alias Avrora.Schema.Name

  describe "parse/1" do
    test "when only name part is present" do
      assert Name.parse("hello") == {:ok, %Name{name: "hello", version: nil}}
      assert Name.parse("io.hello.world") == {:ok, %Name{name: "io.hello.world", version: nil}}
    end

    test "when name and version parts are present" do
      assert Name.parse("hello:6") == {:ok, %Name{name: "hello", version: 6}}
      assert Name.parse("io.hello.world:42") == {:ok, %Name{name: "io.hello.world", version: 42}}
    end
  end
end
