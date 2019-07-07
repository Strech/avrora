defmodule Avrora.FileStorageTest do
  use ExUnit.Case, async: true
  doctest Avrora.FileStorage

  alias Avrora.FileStorage

  describe "get/1" do
    test "when schema file was found" do
      {:ok, avro} = FileStorage.get("io.confluent.examples.Payment")

      assert %AvroEx.Schema{} = avro
      assert avro.schema.qualified_names == ["io.confluent.examples.Payment"]
      assert length(avro.schema.fields) == 2
    end

    test "when schema file is not a valid json" do
      {:error, reason} = FileStorage.get("io.confluent.examples.Wrong")

      assert %Jason.DecodeError{} = reason
    end

    test "when schema file was not found" do
      {:error, reason} = FileStorage.get("io.confluent.examples.Unknown")

      assert :enoent = reason
    end

    test "when schema name was given as a global ID" do
      assert FileStorage.get(42) == {:error, :unsupported}
    end
  end

  describe "put/2" do
    test "when tries to store the schema" do
      assert FileStorage.put(42, %AvroEx.Schema{}) == {:error, :unsupported}
    end
  end
end
