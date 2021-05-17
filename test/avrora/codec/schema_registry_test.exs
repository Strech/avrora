defmodule Avrora.Codec.SchemaRegistryTest do
  use ExUnit.Case, async: true
  doctest Avrora.Codec.SchemaRegistry

  import Mox
  import Support.Config
  import ExUnit.CaptureLog

  alias Avrora.{Codec, Schema, Storage}

  setup :verify_on_exit!
  setup :support_config

  describe "is_decodable/1" do
    test "when payload is a valid binary" do
      assert Codec.SchemaRegistry.is_decodable(payment_message())
    end

    test "when payload is not a valid binary" do
      assert Codec.SchemaRegistry.is_decodable(<<0, 1, 2>>)
    end
  end

  describe "extract_schema/1" do
    test "when payload was valid and registry is not configured" do
      Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, nil}
      end)

      Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:error, :unconfigured_registry_url}
      end)

      assert Codec.SchemaRegistry.extract_schema(payment_message()) ==
               {:error, :unconfigured_registry_url}
    end

    test "when payload is valid and registry is configured" do
      payment_schema_with_id = payment_schema_with_id()

      Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert payment_schema_with_id == value

        {:ok, value}
      end)

      Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, payment_schema_with_id}
      end)

      {:ok, schema} = Codec.SchemaRegistry.extract_schema(payment_message())

      assert schema.id == 42
      assert schema.full_name == "io.confluent.Payment"
      assert schema.json == payment_json_schema()
    end

    test "when payload is invalid" do
      assert Codec.SchemaRegistry.extract_schema(<<79, 98, 106, 1, 0, 1, 2>>) ==
               {:error, :schema_not_found}
    end
  end

  describe "decode/1" do
    test "when payload is valid and registry is configured" do
      payment_schema_with_id = payment_schema_with_id()

      Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == payment_schema_with_id

        {:ok, value}
      end)

      Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, payment_schema_with_id}
      end)

      {:ok, decoded} = Codec.SchemaRegistry.decode(payment_message())
      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload is valid and registry is not configured" do
      Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, nil}
      end)

      Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:error, :unconfigured_registry_url}
      end)

      assert Codec.SchemaRegistry.decode(payment_message()) ==
               {:error, :unconfigured_registry_url}
    end

    test "when payload is not a valid binary" do
      assert Codec.SchemaRegistry.decode(<<0, 1, 2>>) == {:error, :schema_not_found}
    end

    test "when payload is not a valid binary and contains schema id" do
      payment_schema_with_id = payment_schema_with_id()

      Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == payment_schema_with_id

        {:ok, value}
      end)

      Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, payment_schema_with_id}
      end)

      assert Codec.SchemaRegistry.decode(<<0, 0, 0, 0, 42, 72, 48, 48, 48, 48, 48>>) ==
               {:error, :schema_mismatch}
    end
  end

  describe "decode/2" do
    test "when usable schema with id is given" do
      output =
        capture_log(fn ->
          {:ok, decoded} =
            Codec.SchemaRegistry.decode(payment_message(), schema: payment_schema_with_id())

          assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
        end)

      assert output =~
               "message already contains embeded schema id, given schema id will be ignored"
    end

    test "when resolvable schema with id is given" do
      payment_schema_with_id = payment_schema_with_id()

      Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == payment_schema_with_id

        {:ok, value}
      end)

      Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, payment_schema_with_id}
      end)

      output =
        capture_log(fn ->
          {:ok, decoded} =
            Codec.SchemaRegistry.decode(
              payment_message(),
              schema: %Schema{id: 42, full_name: "io.confluent.Payment"}
            )

          assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
        end)

      assert output =~
               "message already contains embeded schema id, given schema id will be ignored"
    end

    test "when resolvable schema without id is given" do
      payment_schema_with_id = %{payment_schema() | id: 9000}

      Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 9000
        assert value == payment_schema_with_id

        {:ok, value}
      end)
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_schema_with_id

        {:ok, value}
      end)
      |> expect(:expire, fn key, ttl ->
        assert key == "io.confluent.Payment"
        assert ttl == :infinity

        {:ok, :infinity}
      end)

      Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:error, :unknown_version}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_json_schema()

        {:ok, payment_schema_with_id}
      end)

      Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema()}
      end)

      output =
        capture_log(fn ->
          {:ok, decoded} =
            Codec.SchemaRegistry.decode(
              payment_message(),
              schema: %Schema{full_name: "io.confluent.Payment"}
            )

          assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
        end)

      assert output =~
               "message embeded schema id is different from the resolved and used schema id"
    end

    test "when payload is not a valid binary" do
      assert Codec.SchemaRegistry.decode(<<0, 1, 2>>, schema: payment_schema_with_id()) ==
               {:error, :schema_not_found}
    end

    test "when payload is not a valid binary and contains schema id" do
      assert Codec.SchemaRegistry.decode(<<0, 0, 0, 0, 42, 72>>, schema: payment_schema_with_id()) ==
               {:error, :schema_mismatch}
    end
  end

  describe "encode/2" do
    test "when payload is not matching the schema" do
      assert Codec.SchemaRegistry.encode(%{"hello" => "world"}, schema: payment_schema_with_id()) ==
               {:error, missing_field_error()}
    end

    test "when resolvable schema without id is given and registry is not configured" do
      payment_schema = payment_schema()

      Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_schema

        {:ok, payment_schema}
      end)

      Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_json_schema()

        {:error, :unconfigured_registry_url}
      end)

      Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema}
      end)

      assert Codec.SchemaRegistry.encode(payment_payload(), schema: payment_schema) ==
               {:error, :invalid_schema_id}
    end

    test "when resolvable schema without id is given" do
      payment_schema_with_id = payment_schema_with_id()
      payment_schema = payment_schema()

      Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == payment_schema_with_id

        {:ok, value}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_schema_with_id

        {:ok, value}
      end)
      |> expect(:expire, fn key, ttl ->
        assert key == "io.confluent.Payment"
        assert ttl == :infinity

        {:ok, :infinity}
      end)

      Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_json_schema()

        {:ok, payment_schema_with_id}
      end)

      Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema}
      end)

      assert Codec.SchemaRegistry.encode(payment_payload(), schema: payment_schema) ==
               {:ok, payment_message()}
    end

    test "when usable schema with id is given" do
      assert Codec.SchemaRegistry.encode(payment_payload(), schema: payment_schema_with_id()) ==
               {:ok, payment_message()}
    end
  end

  defp missing_field_error do
    %ErlangError{
      original:
        {:"$avro_encode_error", :required_field_missed,
         [record: "io.confluent.Payment", field: "id"]}
    }
  end

  defp payment_schema_with_id do
    {:ok, schema} = Schema.Codec.from_json(payment_json_schema())
    %{schema | id: 42, version: nil}
  end

  defp payment_schema do
    {:ok, schema} = Schema.Codec.from_json(payment_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp payment_json_schema do
    ~s({"namespace":"io.confluent","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end

  defp payment_payload, do: %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}

  defp payment_message do
    <<0, 0, 0, 0, 42, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48,
      45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71,
      225, 250, 47, 64>>
  end
end
