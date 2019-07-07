defmodule Avrora.SchemaLoaderTest do
  use ExUnit.Case, async: true
  doctest Avrora.SchemaLoader

  alias Avrora.SchemaLoader

  describe "load/1" do
    test "when schema file was found" do
      {state, schema} = SchemaLoader.load("io.confluent.examples.Payment")

      assert state

      assert schema == %{
               "name" => "Payment",
               "namespace" => "io.confluent.examples",
               "type" => "record",
               "fields" => [
                 %{"name" => "id", "type" => "string"},
                 %{"name" => "amount", "type" => "double"}
               ]
             }
    end

    test "when schema file is not a valid json" do
      {state, reason} = SchemaLoader.load("io.confluent.examples.Wrong")

      assert state == :error
      assert %Jason.DecodeError{} = reason
    end

    test "when schmea file was not found" do
      {state, reason} = SchemaLoader.load("io.confluent.examples.Unknown")

      assert state == :error
      assert :enoent = reason
    end
  end
end
