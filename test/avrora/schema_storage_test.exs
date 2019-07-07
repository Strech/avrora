defmodule Avrora.SchemaStorageTest do
  use ExUnit.Case, async: true
  doctest Avrora.SchemaStorage

  alias Avrora.SchemaStorage

  setup do
    pid = start_supervised!({SchemaStorage, name: :test_schema_storage})

    %{schema_storage: pid}
  end

  describe "put/3" do
    test "when key is new", %{schema_storage: pid} do
      assert SchemaStorage.get(pid, "my-key") == nil
      assert SchemaStorage.put(pid, "my-key", "lorem ipsum")
      assert SchemaStorage.get(pid, "my-key") == "lorem ipsum"
    end

    test "when key already exists", %{schema_storage: pid} do
      _ = SchemaStorage.put(pid, "my-key", "lorem ipsum")

      assert SchemaStorage.get(pid, "my-key") == "lorem ipsum"
      assert SchemaStorage.put(pid, "my-key", %{"hello" => "world"})
      assert SchemaStorage.get(pid, "my-key") == %{"hello" => "world"}
    end
  end

  describe "get/2" do
    test "when key already exists", %{schema_storage: pid} do
      _ = SchemaStorage.put(pid, "my-key", "lorem ipsum")

      assert SchemaStorage.get(pid, "my-key") == "lorem ipsum"
    end

    test "when key does not exist", %{schema_storage: pid} do
      assert SchemaStorage.get(pid, "my-key") == nil
    end
  end
end
