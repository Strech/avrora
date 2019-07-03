defmodule AvroraTest do
  use ExUnit.Case
  doctest Avrora

  test "greets the world" do
    assert Avrora.hello() == :world
  end
end
