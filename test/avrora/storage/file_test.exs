defmodule Avrora.Storage.FileTest do
  use ExUnit.Case, async: true
  doctest Avrora.Storage.File

  import ExUnit.CaptureLog
  alias Avrora.Storage.File

  describe "get/1" do
    test "when schema file was found" do
      {:ok, schema} = File.get("io.confluent.Payment")

      assert schema.full_name == "io.confluent.Payment"
    end

    test "when schema name contains version and when schema file was found" do
      output =
        capture_log(fn ->
          {:ok, schema} = File.get("io.confluent.Payment:42")

          assert schema.full_name == "io.confluent.Payment"
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
