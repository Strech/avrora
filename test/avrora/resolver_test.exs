defmodule Avrora.ResolverTest do
  use ExUnit.Case, async: true
  doctest Avrora.Resolver

  import Mox
  import Support.Config
  import ExUnit.CaptureLog
  alias Avrora.{Resolver, Schema}

  setup :verify_on_exit!
  setup :support_config

  describe "resolve_any/1" do
    test "when registry is configured and schema was not found in memory, but registry" do
      schema_with_id = schema_with_id()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 1

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 1
        assert value == schema_with_id

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 1

        {:ok, schema_with_id}
      end)

      {:ok, schema} = Resolver.resolve_any([1, "io.confluent.Payment"])

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when registry is configured, but failing and schema was not found in a memory and found in a file" do
      schema_without_id_and_version = schema_without_id_and_version()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 1

        {:ok, nil}
      end)
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 1

        {:error, :unknown_subject}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == json_schema()

        {:error, :unknown_error}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema_without_id_and_version}
      end)

      output =
        capture_log(fn ->
          assert {:error, :unknown_error} == Resolver.resolve_any([1, "io.confluent.Payment"])
        end)

      assert output =~ "fail to resolve schema by identifier"
    end

    test "when registry is configured, but failing and schema was not found in a memory and not found in a file" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 1

        {:ok, nil}
      end)
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 1

        {:error, :unknown_subject}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :enoent}
      end)

      output =
        capture_log(fn ->
          assert {:error, :enoent} = Resolver.resolve_any([1, "io.confluent.Payment"])
        end)

      assert output =~ "fail to resolve schema by identifier"
    end

    test "when registry is not configured and schema was not found in memory" do
      schema_without_id_and_version = schema_without_id_and_version()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 1

        {:ok, nil}
      end)
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema_without_id_and_version

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 1

        {:error, :unconfigured_registry_url}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == json_schema()

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema_without_id_and_version}
      end)

      {:ok, schema} = Resolver.resolve_any([1, "io.confluent.Payment"])

      assert is_nil(schema.id)
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end
  end

  describe "resolve/1" do
    test "when global ID is given and it was found in a memory" do
      schema_with_id = schema_with_id()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 1

        {:ok, schema_with_id}
      end)

      {:ok, schema} = Resolver.resolve(1)

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when global ID is given and it was not found in a memory" do
      schema_with_id = schema_with_id()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 1

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 1
        assert value == schema_with_id

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 1

        {:ok, schema_with_id}
      end)

      {:ok, schema} = Resolver.resolve(1)

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when global ID is given and it was not found in a memory and in a registry" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 1

        {:ok, nil}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 1

        {:error, :unknown_subject}
      end)

      assert Resolver.resolve(1) == {:error, :unknown_subject}
    end

    test "when schema name is given and it was not found in a memory, but registry" do
      schema_with_id = schema_with_id()
      schema_without_id_and_version = schema_without_id_and_version()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 1
        assert value == schema_with_id

        {:ok, value}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema_with_id

        {:ok, value}
      end)
      |> expect(:expire, fn key, ttl ->
        assert key == "io.confluent.Payment"
        assert ttl == :infinity

        {:ok, :infinity}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema_without_id_and_version}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == json_schema()

        {:ok, schema_with_id}
      end)

      {:ok, schema} = Resolver.resolve("io.confluent.Payment")

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when schema name with version is given and it was not found in a memory and in a registry" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"

        {:ok, nil}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"

        {:ok, schema_without_id_and_version()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"

        {:error, :unknown_version}
      end)

      assert Resolver.resolve("io.confluent.Payment:3") == {:error, :unknown_version}
    end

    test "when schema name is given and it was not found in a memory and registry is not configured" do
      schema_without_id_and_version = schema_without_id_and_version()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema_without_id_and_version

        {:ok, value}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema_without_id_and_version}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == json_schema()

        {:error, :unconfigured_registry_url}
      end)

      {:ok, schema} = Resolver.resolve("io.confluent.Payment")

      assert is_nil(schema.id)
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when schema name with version is given and it was not found in a memory and registry is not configured" do
      schema_without_id_and_version = schema_without_id_and_version()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema_without_id_and_version

        {:ok, value}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"

        {:ok, schema_without_id_and_version}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"

        {:error, :unconfigured_registry_url}
      end)

      {:ok, schema} = Resolver.resolve("io.confluent.Payment:3")

      assert is_nil(schema.id)
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when schema name with version is given and it was not found in a memory, but registry" do
      schema_with_id_and_version = schema_with_id_and_version()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == schema_with_id_and_version

        {:ok, value}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema_with_id_and_version

        {:ok, value}
      end)
      |> expect(:expire, fn key, ttl ->
        assert key == "io.confluent.Payment"
        assert ttl == :infinity

        {:ok, :infinity}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment:3"
        assert value == schema_with_id_and_version

        {:ok, value}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"

        {:ok, schema_without_id_and_version()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"

        {:ok, schema_with_id_and_version}
      end)

      {:ok, schema} = Resolver.resolve("io.confluent.Payment:3")

      assert schema.id == 42
      assert schema.version == 3
      assert schema.full_name == "io.confluent.Payment"
    end
  end

  defp schema_without_id_and_version do
    {:ok, schema} = Schema.parse(json_schema())
    %{schema | id: nil, version: nil}
  end

  defp schema_with_id do
    {:ok, schema} = Schema.parse(json_schema())
    %{schema | id: 1, version: nil}
  end

  defp schema_with_id_and_version do
    {:ok, schema} = Schema.parse(json_schema())
    %{schema | id: 42, version: 3}
  end

  defp json_schema do
    ~s({"namespace":"io.confluent","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end
end
