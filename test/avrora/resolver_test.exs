defmodule Avrora.ResolverTest do
  use ExUnit.Case, async: true
  doctest Avrora.Resolver

  import Mox
  alias Avrora.Resolver

  describe "resolve/1" do
    test "when global ID is given and it was found in a memory" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 1
        {:ok, schema_with_id()}
      end)

      {:ok, avro} = Resolver.resolve(1)
      {type, _, _, _, _, fields, full_name, _} = avro.schema

      assert avro.id == 1
      assert is_nil(avro.version)
      assert type == :avro_record_type
      assert full_name == "io.confluent.Payment"
      assert length(fields) == 2
    end

    test "when global ID is given and it was not found in a memory" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 1
        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 1
        assert value == schema_with_id()
        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 1
        {:ok, schema_with_id()}
      end)

      {:ok, avro} = Resolver.resolve(1)
      {type, _, _, _, _, fields, full_name, _} = avro.schema

      assert avro.id == 1
      assert is_nil(avro.version)
      assert type == :avro_record_type
      assert full_name == "io.confluent.Payment"
      assert length(fields) == 2
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
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == schema_with_id_and_version()

        {:ok, value}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment:3"
        assert value == schema_with_id_and_version()

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema_with_id_and_version()}
      end)

      {:ok, avro} = Resolver.resolve("io.confluent.Payment")
      {type, _, _, _, _, fields, full_name, _} = avro.schema

      assert avro.id == 42
      assert avro.version == 3
      assert type == :avro_record_type
      assert full_name == "io.confluent.Payment"
      assert length(fields) == 2
    end

    test "when schema name is given and it was not found in a memory and in a registry" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 1
        assert value == schema_with_id()

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unknown_subject}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == raw_schema()

        {:ok, schema_with_id()}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema()}
      end)

      {:ok, avro} = Resolver.resolve("io.confluent.Payment")
      {type, _, _, _, _, fields, full_name, _} = avro.schema

      assert avro.id == 1
      assert is_nil(avro.version)
      assert type == :avro_record_type
      assert full_name == "io.confluent.Payment"
      assert length(fields) == 2
    end

    test "when schema name with version is given and it was not found in a memory and in a registry" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"

        {:ok, nil}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"

        {:error, :unknown_version}
      end)

      assert Resolver.resolve("io.confluent.Payment:3") == {:error, :unknown_version}
    end

    test "when schema name is given and it was not found in a memory and registry is not configured" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema()

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema()}
      end)

      {:ok, avro} = Resolver.resolve("io.confluent.Payment")
      {type, _, _, _, _, fields, full_name, _} = avro.schema

      assert is_nil(avro.id)
      assert is_nil(avro.version)
      assert type == :avro_record_type
      assert full_name == "io.confluent.Payment"
      assert length(fields) == 2
    end

    test "when schema name with version is given and it was not found in a memory and registry is not configured" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"
        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema()

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"
        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:3"
        {:ok, schema()}
      end)

      {:ok, avro} = Resolver.resolve("io.confluent.Payment:3")
      {type, _, _, _, _, fields, full_name, _} = avro.schema

      assert is_nil(avro.id)
      assert is_nil(avro.version)
      assert type == :avro_record_type
      assert full_name == "io.confluent.Payment"
      assert length(fields) == 2
    end
  end

  defp schema do
    %Avrora.Schema{
      id: nil,
      version: nil,
      schema: erlavro_schema(),
      raw_schema: raw_schema()
    }
  end

  defp schema_with_id do
    %Avrora.Schema{
      id: 1,
      version: nil,
      schema: erlavro_schema(),
      raw_schema: raw_schema()
    }
  end

  defp schema_with_id_and_version do
    %Avrora.Schema{
      id: 42,
      version: 3,
      schema: erlavro_schema(),
      raw_schema: raw_schema()
    }
  end

  defp erlavro_schema do
    :avro_json_decoder.decode_schema(raw_schema())
  end

  defp raw_schema do
    ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end
end
