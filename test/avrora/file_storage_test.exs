defmodule Avrora.FileStorageTest do
  use ExUnit.Case, async: true
  doctest Avrora.FileStorage

  alias Avrora.FileStorage

  describe "get/1" do
    test "when schema file was found" do
      {:ok, avro} = FileStorage.get("io.confluent.Payment")

      assert %Avrora.Schema{} = avro
      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert length(avro.ex_schema.schema.fields) == 2
      assert length(Map.get(avro.raw_schema, "fields")) == 2
    end

    test "when schema file is not a valid json" do
      {:error, reason} = FileStorage.get("io.confluent.Wrong")

      assert %Jason.DecodeError{} = reason
    end

    test "when schema file was not found" do
      {:error, reason} = FileStorage.get("io.confluent.Unknown")

      assert :enoent = reason
    end

    test "when schema name was given as a global ID" do
      assert FileStorage.get(42) == {:error, :unsupported}
    end
  end

  describe "put/2" do
    test "when tries to store the schema" do
      assert FileStorage.put(42, %Avrora.Schema{}) == {:error, :unsupported}
    end
  end
end
