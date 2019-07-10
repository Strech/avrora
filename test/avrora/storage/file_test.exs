defmodule Avrora.Storage.FileTest do
  use ExUnit.Case, async: true
  doctest Avrora.Storage.File

  import ExUnit.CaptureLog
  alias Avrora.Storage.File

  describe "get/1" do
    test "when schema file was found" do
      {:ok, avro} = File.get("io.confluent.Payment")

      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert length(avro.ex_schema.schema.fields) == 2
      assert length(Map.get(avro.raw_schema, "fields")) == 2
    end

    test "when schema name contains version and when schema file was found" do
      output =
        capture_log(fn ->
          {:ok, avro} = File.get("io.confluent.Payment:42")

          assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
          assert length(avro.ex_schema.schema.fields) == 2
          assert length(Map.get(avro.raw_schema, "fields")) == 2
        end)

      assert output =~ "schema with version is not allowed"
    end

    test "when schema file is not a valid json" do
      {:error, reason} = File.get("io.confluent.Wrong")

      assert %Jason.DecodeError{} = reason
    end

    test "when schema file was not found" do
      {:error, reason} = File.get("io.confluent.Unknown")

      assert :enoent = reason
    end

    test "when schema name was given as a global ID" do
      assert File.get(42) == {:error, :unsupported}
    end
  end

  describe "put/2" do
    test "when tries to store the schema" do
      assert File.put(42, %Avrora.Schema{}) == {:error, :unsupported}
    end
  end
end
