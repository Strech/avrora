defmodule Avrora.Utils.RegistratorTest do
  use ExUnit.Case, async: true
  doctest Avrora.Utils.Registrator

  import Mox
  import Support.Config
  import ExUnit.CaptureLog
  alias Avrora.Schema
  alias Avrora.Utils.Registrator

  setup :verify_on_exit!
  setup :support_config

  describe "register_schema/2" do
    test "when registry is not configured" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == json_schema()

        {:error, :unconfigured_registry_url}
      end)

      assert {:error, :unconfigured_registry_url} ==
               Registrator.register_schema(schema_without_id_and_version())
    end

    test "when schema was found in memory" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema_with_id()}
      end)

      {:ok, schema} = Registrator.register_schema(schema_without_id_and_version())

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when schema should be registered under specific name" do
      schema_with_id = schema_with_id()

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

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "MyCustomName"
        assert value == json_schema()

        {:ok, schema_with_id}
      end)

      {:ok, schema} =
        Registrator.register_schema(schema_without_id_and_version(), as: "MyCustomName")

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when schema was found in memory and forced to be registered" do
      schema_with_id = schema_with_id()

      Avrora.Storage.MemoryMock
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

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == json_schema()

        {:ok, schema_with_id}
      end)

      {:ok, schema} = Registrator.register_schema(schema_without_id_and_version(), force: true)

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when schema contains version and was not found in memory" do
      schema_with_id = schema_with_id()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:2"

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

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment:2"
        assert value == json_schema()

        {:ok, schema_with_id}
      end)

      output =
        capture_log(fn ->
          {:ok, schema} = Registrator.register_schema(schema_with_version())

          assert schema.id == 1
          assert is_nil(schema.version)
          assert schema.full_name == "io.confluent.Payment"
        end)

      assert output =~ "schema `io.confluent.Payment` will be always resolved from memory"
    end

    test "when schema contains id and was not found in memory" do
      schema_with_id = schema_with_id()

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

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == json_schema()

        {:ok, schema_with_id}
      end)

      {:ok, schema} = Registrator.register_schema(schema_with_id)

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end
  end

  # TODO
  describe "register_schema_by_name/2" do
  end

  defp schema_without_id_and_version do
    {:ok, schema} = Schema.parse(json_schema())
    %{schema | id: nil, version: nil}
  end

  defp schema_with_id do
    {:ok, schema} = Schema.parse(json_schema())
    %{schema | id: 1, version: nil}
  end

  defp schema_with_version do
    {:ok, schema} = Schema.parse(json_schema())
    %{schema | id: nil, version: 2}
  end

  defp json_schema do
    ~s({"namespace":"io.confluent","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end
end
