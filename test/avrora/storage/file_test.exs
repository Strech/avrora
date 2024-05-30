defmodule Avrora.Storage.FileTest do
  use ExUnit.Case, async: true
  doctest Avrora.Storage.File

  import Support.Config
  import ExUnit.CaptureLog
  alias Avrora.Storage.File

  setup :support_config

  describe "get/1" do
    test "when schema file contains named type" do
      {:ok, schema} = File.get("io.acme.Payment")

      assert schema.full_name == "io.acme.Payment"
    end

    test "when schema file contains named type with nested references" do
      output =
        capture_log(fn ->
          {:ok, schema} = File.get("io.acme.Account")

          assert schema.full_name == "io.acme.Account"
        end)

      assert output =~ "reading schema `io.acme.Account`"
      assert output =~ "reading schema `io.acme.PaymentHistory`"
      assert output =~ "reading schema `io.acme.Payment`"
      assert output =~ "reading schema `io.acme.Messenger`"
      assert output =~ "reading schema `io.acme.Email`"
      assert output =~ "reading schema `io.acme.Image`"
      assert output =~ "reading schema `io.acme.File`"

      assert length(Regex.scan(~r/reading schema .*`/, output)) == 7
    end

    test "when schema name contains version and when schema file was found" do
      output =
        capture_log(fn ->
          {:ok, schema} = File.get("io.acme.Payment:42")

          assert schema.full_name == "io.acme.Payment"
        end)

      assert output =~ "schema file with version is not allowed"
    end

    test "when schema file contains invalid json" do
      assert File.get("io.acme.Wrong") == {:error, "argument error"}
    end

    test "when schema file was not found" do
      assert File.get("io.acme.Unknown") == {:error, :enoent}
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
