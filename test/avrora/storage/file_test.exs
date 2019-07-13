defmodule Avrora.Storage.FileTest do
  use ExUnit.Case, async: true
  doctest Avrora.Storage.File

  import ExUnit.CaptureLog
  alias Avrora.Storage.File

  describe "get/1" do
    test "when schema file was found" do
      {:ok, avro} = File.get("io.confluent.Payment")
      {type, _, _, _, _, fields, full_name, _} = avro.schema

      assert type == :avro_record_type
      assert full_name == "io.confluent.Payment"
      assert length(fields) == 2
    end

    test "when schema name contains version and when schema file was found" do
      output =
        capture_log(fn ->
          {:ok, avro} = File.get("io.confluent.Payment:42")
          {type, _, _, _, _, fields, full_name, _} = avro.schema

          assert type == :avro_record_type
          assert full_name == "io.confluent.Payment"
          assert length(fields) == 2
        end)

      assert output =~ "schema with version is not allowed"
    end

    test "when schema file is not a valid json" do
      assert File.get("io.confluent.Wrong") == {:error, "argument error"}
    end

    test "when schema file was not found" do
      assert File.get("io.confluent.Unknown") == {:error, :enoent}
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
