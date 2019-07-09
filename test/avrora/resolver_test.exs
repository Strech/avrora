defmodule Avrora.ResolverTest do
  use ExUnit.Case, async: true
  doctest Avrora.Resolver

  import Mox

  alias Avrora.Resolver

  describe "resolve/1" do
    test "when global ID is given and it was found in a memory" do
      Avrora.MemoryStorageMock
      |> expect(:get, fn key ->
        assert key == 1
        {:ok, schema_with_id()}
      end)

      {:ok, avro} = Resolver.resolve(1)

      assert avro.id == 1
      assert is_nil(avro.version)
      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert Map.get(avro.raw_schema, "name") == "Payment"
    end

    test "when global ID is given and it was not found in a memory" do
      Avrora.MemoryStorageMock
      |> expect(:get, fn key ->
        assert key == 1
        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 1
        assert value == schema_with_id()
        {:ok, value}
      end)

      Avrora.RegistryStorageMock
      |> expect(:get, fn key ->
        assert key == 1
        {:ok, schema_with_id()}
      end)

      {:ok, avro} = Resolver.resolve(1)

      assert avro.id == 1
      assert is_nil(avro.version)
      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert Map.get(avro.raw_schema, "name") == "Payment"
    end

    test "when global ID is given and it was not found in a memory and in a registry" do
      Avrora.MemoryStorageMock
      |> expect(:get, fn key ->
        assert key == 1
        {:ok, nil}
      end)

      Avrora.RegistryStorageMock
      |> expect(:get, fn key ->
        assert key == 1
        {:error, :unknown_subject}
      end)

      assert Resolver.resolve(1) == {:error, :unknown_subject}
    end

    test "when schema name is given and it was not found in a memory, but registry" do
      Avrora.MemoryStorageMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema_with_version()

        {:ok, value}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment:42"
        assert value == schema_with_version()

        {:ok, value}
      end)

      Avrora.RegistryStorageMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema_with_version()}
      end)

      {:ok, avro} = Resolver.resolve("io.confluent.Payment")

      assert is_nil(avro.id)
      assert avro.version == 42
      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert Map.get(avro.raw_schema, "name") == "Payment"
    end

    test "when schema name is given and it was not found in a memory and in a registry" do
      Avrora.MemoryStorageMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema_with_version()

        {:ok, value}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment:42"
        assert value == schema_with_version()

        {:ok, value}
      end)

      Avrora.RegistryStorageMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unknown_subject}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == raw_schema()

        {:ok, schema_with_version()}
      end)

      Avrora.FileStorageMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema()}
      end)

      {:ok, avro} = Resolver.resolve("io.confluent.Payment")

      assert is_nil(avro.id)
      assert avro.version == 42
      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert Map.get(avro.raw_schema, "name") == "Payment"
    end

    test "when schema name with version is given and it was not found in a memory and in a registry" do
      Avrora.MemoryStorageMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:42"

        {:ok, nil}
      end)

      Avrora.RegistryStorageMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:42"

        {:error, :unknown_version}
      end)

      assert Resolver.resolve("io.confluent.Payment:42") == {:error, :unknown_version}
    end

    test "when schema name is given and it was not found in a memory and registry is not configured" do
      Avrora.MemoryStorageMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema()

        {:ok, value}
      end)

      Avrora.RegistryStorageMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.FileStorageMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema()}
      end)

      {:ok, avro} = Resolver.resolve("io.confluent.Payment")

      assert is_nil(avro.id)
      assert is_nil(avro.version)
      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert Map.get(avro.raw_schema, "name") == "Payment"
    end

    test "when schema name:version is given and it was not found in a memory and registry is not configured" do
      Avrora.MemoryStorageMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:42"
        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema()

        {:ok, value}
      end)

      Avrora.RegistryStorageMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:42"
        {:error, :unconfigured_registry_url}
      end)

      Avrora.FileStorageMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"
        {:ok, schema()}
      end)

      {:ok, avro} = Resolver.resolve("io.confluent.Payment:42")

      assert is_nil(avro.id)
      assert is_nil(avro.version)
      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert Map.get(avro.raw_schema, "name") == "Payment"
    end
  end

  defp schema do
    %Avrora.Schema{
      id: nil,
      version: nil,
      ex_schema: ex_schema(),
      raw_schema: raw_schema()
    }
  end

  defp schema_with_id do
    %Avrora.Schema{
      id: 1,
      version: nil,
      ex_schema: ex_schema(),
      raw_schema: raw_schema()
    }
  end

  defp schema_with_version do
    %Avrora.Schema{
      id: nil,
      version: 42,
      ex_schema: ex_schema(),
      raw_schema: raw_schema()
    }
  end

  defp ex_schema do
    AvroEx.Schema.parse!(Jason.encode!(raw_schema()))
  end

  defp raw_schema do
    %{
      "namespace" => "io.confluent",
      "type" => "record",
      "name" => "Payment",
      "fields" => [
        %{"name" => "id", "type" => "string"},
        %{"name" => "amount", "type" => "double"}
      ]
    }
  end
end
