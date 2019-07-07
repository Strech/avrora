defmodule Avrora.MemoryStorageTest do
  use ExUnit.Case, async: true
  doctest Avrora.MemoryStorage

  alias Avrora.MemoryStorage

  setup do
    pid = start_supervised!({MemoryStorage, name: :test_schema_storage})

    %{schema_storage: pid}
  end

  describe "put/3" do
    test "when key is new", %{schema_storage: pid} do
      assert MemoryStorage.get(pid, "my-key") == {:ok, nil}
      assert MemoryStorage.put(pid, "my-key", "lorem ipsum") == {:ok, "lorem ipsum"}
      assert MemoryStorage.get(pid, "my-key") == {:ok, "lorem ipsum"}
    end

    test "when key already exists", %{schema_storage: pid} do
      {:ok, _} = MemoryStorage.put(pid, "my-key", "lorem ipsum")

      assert MemoryStorage.get(pid, "my-key") == {:ok, "lorem ipsum"}
      assert MemoryStorage.put(pid, "my-key", ["one"]) == {:ok, ["one"]}
      assert MemoryStorage.get(pid, "my-key") == {:ok, ["one"]}
    end
  end

  describe "get/2" do
    test "when key already exists", %{schema_storage: pid} do
      {:ok, _} = MemoryStorage.put(pid, "my-key", "lorem ipsum")

      assert MemoryStorage.get(pid, "my-key") == {:ok, "lorem ipsum"}
    end

    test "when key does not exist", %{schema_storage: pid} do
      assert MemoryStorage.get(pid, "my-key") == {:ok, nil}
    end
  end
end
