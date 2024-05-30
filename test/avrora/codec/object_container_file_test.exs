defmodule Avrora.Codec.ObjectContainerFileTest do
  use ExUnit.Case, async: true
  doctest Avrora.Codec.ObjectContainerFile

  import Mox
  import Support.Config
  import ExUnit.CaptureLog

  alias Avrora.{Codec, Schema, Storage}

  setup :verify_on_exit!
  setup :support_config

  describe "is_decodable/1" do
    test "when payload is a valid binary" do
      assert Codec.ObjectContainerFile.is_decodable(payment_message())
    end

    test "when payload is not a valid binary" do
      refute Codec.ObjectContainerFile.is_decodable(<<0, 1, 2>>)
    end
  end

  describe "extract_schema/1" do
    test "when payload is valid and contains schema but nothing found in memory" do
      payment_json_schema = payment_json_schema()

      Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Payment"
        assert value.json == payment_json_schema

        {:ok, value}
      end)

      {:ok, schema} = Codec.ObjectContainerFile.extract_schema(payment_message())

      assert is_nil(schema.id)
      assert is_nil(schema.version)

      assert schema.full_name == "io.acme.Payment"
      assert schema.json == payment_json_schema
    end

    test "when payload is valid and contains schema which found in memory" do
      Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, payment_schema()}
      end)

      {:ok, schema} = Codec.ObjectContainerFile.extract_schema(payment_message())

      assert is_nil(schema.id)
      assert is_nil(schema.version)

      assert schema.full_name == "io.acme.Payment"
      assert schema.json == payment_json_schema()
    end

    test "when payload is invalid" do
      assert Codec.ObjectContainerFile.extract_schema(<<79, 98, 106, 1, 0, 1, 2>>) == {:error, :schema_mismatch}
    end
  end

  describe "decode/2" do
    test "when payload is a valid binary and schema is not given" do
      {:ok, decoded} = Codec.ObjectContainerFile.decode(payment_message())

      assert decoded == [%{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}]
    end

    test "when payload is a valid binary and null values must be as is" do
      stub(Avrora.ConfigMock, :convert_null_values, fn -> false end)

      {:ok, decoded} = Codec.ObjectContainerFile.decode(null_value_message(), schema: null_value_schema())

      assert decoded == [%{"key" => "user-1", "value" => :null}]
    end

    test "when payload is a valid binary and null values must be converted" do
      {:ok, decoded} = Codec.ObjectContainerFile.decode(null_value_message(), schema: null_value_schema())

      assert decoded == [%{"key" => "user-1", "value" => nil}]
    end

    test "when payload is a valid binary and map type must be decoded as proplist" do
      stub(Avrora.ConfigMock, :convert_map_to_proplist, fn -> true end)

      {:ok, decoded} = Codec.ObjectContainerFile.decode(map_message())

      assert decoded == [%{"map_field" => [{"key", "value"}]}]
    end

    test "when payload is a valid binary and map type must be decoded as map" do
      {:ok, decoded} = Codec.ObjectContainerFile.decode(map_message())

      assert decoded == [%{"map_field" => %{"key" => "value"}}]
    end

    test "when payload is not a valid binary and schema is not given" do
      assert Codec.ObjectContainerFile.decode(<<79, 98, 106, 1, 0, 1, 2>>) == {:error, :schema_mismatch}
    end

    test "when payload is a valid binary and schema is given" do
      output =
        capture_log(fn ->
          {:ok, decoded} = Codec.ObjectContainerFile.decode(payment_message(), schema: payment_schema())

          assert decoded == [%{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}]
        end)

      assert output =~ "message already contains embeded schema, given schema will be ignored"
    end
  end

  describe "encode/2" do
    test "when payload is not matching the schema" do
      assert Codec.ObjectContainerFile.encode(%{"hello" => "world"}, schema: payment_schema()) ==
               {:error, missing_field_error()}
    end

    test "when payload is matching the schema and schema is unusable" do
      assert Codec.ObjectContainerFile.encode(payment_payload(), schema: %Schema{}) == {:error, :unusable_schema}
    end

    test "when payload is matching the schema and schema is usable" do
      {:ok, encoded} = Codec.ObjectContainerFile.encode(payment_payload(), schema: payment_schema())

      assert is_payment_ocf(encoded)
    end

    test "when payload is matching the schema and schema is resolvable" do
      payment_schema = payment_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Payment"
        assert value == payment_schema

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Payment"
        assert value == payment_json_schema()

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, payment_schema}
      end)

      {:ok, encoded} =
        Codec.ObjectContainerFile.encode(
          payment_payload(),
          schema: %Schema{full_name: "io.acme.Payment"}
        )

      assert is_payment_ocf(encoded)
    end
  end

  defp missing_field_error do
    %ErlangError{
      original: {:"$avro_encode_error", :required_field_missed, [record: "io.acme.Payment", field: "id"]}
    }
  end

  # byte_size(<< message container binary >>) * 8
  defp is_payment_ocf(payload) do
    match?(
      <<79, 98, 106, 1, _::size(1464), 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45,
        48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64,
        _::binary>>,
      payload
    )
  end

  defp payment_schema do
    {:ok, schema} = Schema.Encoder.from_json(payment_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp null_value_schema do
    {:ok, schema} = Schema.Encoder.from_json(null_value_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp payment_payload, do: %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}

  defp payment_json_schema do
    ~s({"namespace":"io.acme","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end

  defp null_value_json_schema do
    ~s({"namespace":"io.acme","name":"NullValue","type":"record","fields":[{"name":"key","type":"string"},{"name":"value","type":["null","int"]}]})
  end

  # %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
  defp payment_message do
    <<79, 98, 106, 1, 3, 194, 2, 20, 97, 118, 114, 111, 46, 99, 111, 100, 101, 99, 8, 110, 117, 108, 108, 22, 97, 118,
      114, 111, 46, 115, 99, 104, 101, 109, 97, 134, 2, 123, 34, 110, 97, 109, 101, 115, 112, 97, 99, 101, 34, 58, 34,
      105, 111, 46, 97, 99, 109, 101, 34, 44, 34, 110, 97, 109, 101, 34, 58, 34, 80, 97, 121, 109, 101, 110, 116, 34,
      44, 34, 116, 121, 112, 101, 34, 58, 34, 114, 101, 99, 111, 114, 100, 34, 44, 34, 102, 105, 101, 108, 100, 115, 34,
      58, 91, 123, 34, 110, 97, 109, 101, 34, 58, 34, 105, 100, 34, 44, 34, 116, 121, 112, 101, 34, 58, 34, 115, 116,
      114, 105, 110, 103, 34, 125, 44, 123, 34, 110, 97, 109, 101, 34, 58, 34, 97, 109, 111, 117, 110, 116, 34, 44, 34,
      116, 121, 112, 101, 34, 58, 34, 100, 111, 117, 98, 108, 101, 34, 125, 93, 125, 0, 4, 195, 100, 164, 209, 162, 89,
      224, 176, 130, 30, 95, 252, 255, 232, 220, 2, 90, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48,
      48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250,
      47, 64, 4, 195, 100, 164, 209, 162, 89, 224, 176, 130, 30, 95, 252, 255, 232, 220>>
  end

  # %{"key" => "user-1", "value" => nil}
  defp null_value_message do
    <<79, 98, 106, 1, 3, 210, 2, 20, 97, 118, 114, 111, 46, 99, 111, 100, 101, 99, 8, 110, 117, 108, 108, 22, 97, 118,
      114, 111, 46, 115, 99, 104, 101, 109, 97, 150, 2, 123, 34, 110, 97, 109, 101, 115, 112, 97, 99, 101, 34, 58, 34,
      105, 111, 46, 97, 99, 109, 101, 34, 44, 34, 110, 97, 109, 101, 34, 58, 34, 78, 117, 108, 108, 86, 97, 108, 117,
      101, 34, 44, 34, 116, 121, 112, 101, 34, 58, 34, 114, 101, 99, 111, 114, 100, 34, 44, 34, 102, 105, 101, 108, 100,
      115, 34, 58, 91, 123, 34, 110, 97, 109, 101, 34, 58, 34, 107, 101, 121, 34, 44, 34, 116, 121, 112, 101, 34, 58,
      34, 115, 116, 114, 105, 110, 103, 34, 125, 44, 123, 34, 110, 97, 109, 101, 34, 58, 34, 118, 97, 108, 117, 101, 34,
      44, 34, 116, 121, 112, 101, 34, 58, 91, 34, 110, 117, 108, 108, 34, 44, 34, 105, 110, 116, 34, 93, 125, 93, 125,
      0, 115, 69, 156, 136, 92, 15, 29, 224, 201, 252, 144, 71, 34, 225, 172, 111, 2, 16, 12, 117, 115, 101, 114, 45,
      49, 0, 115, 69, 156, 136, 92, 15, 29, 224, 201, 252, 144, 71, 34, 225, 172, 111>>
  end

  # {"namespace":"io.acme","name":"MapValue","type":"record","fields":[{"name":"map_field","type":{"type":"map","values":"string"}}]}
  # %{"map_field" => %{"key" => "value"}}
  defp map_message do
    <<79, 98, 106, 1, 3, 190, 2, 20, 97, 118, 114, 111, 46, 99, 111, 100, 101, 99, 8, 110, 117, 108, 108, 22, 97, 118,
      114, 111, 46, 115, 99, 104, 101, 109, 97, 130, 2, 123, 34, 110, 97, 109, 101, 115, 112, 97, 99, 101, 34, 58, 34,
      105, 111, 46, 97, 99, 109, 101, 34, 44, 34, 110, 97, 109, 101, 34, 58, 34, 77, 97, 112, 86, 97, 108, 117, 101, 34,
      44, 34, 116, 121, 112, 101, 34, 58, 34, 114, 101, 99, 111, 114, 100, 34, 44, 34, 102, 105, 101, 108, 100, 115, 34,
      58, 91, 123, 34, 110, 97, 109, 101, 34, 58, 34, 109, 97, 112, 95, 102, 105, 101, 108, 100, 34, 44, 34, 116, 121,
      112, 101, 34, 58, 123, 34, 116, 121, 112, 101, 34, 58, 34, 109, 97, 112, 34, 44, 34, 118, 97, 108, 117, 101, 115,
      34, 58, 34, 115, 116, 114, 105, 110, 103, 34, 125, 125, 93, 125, 0, 96, 8, 63, 200, 147, 9, 150, 117, 64, 6, 235,
      49, 39, 34, 107, 111, 2, 26, 1, 20, 6, 107, 101, 121, 10, 118, 97, 108, 117, 101, 0, 96, 8, 63, 200, 147, 9, 150,
      117, 64, 6, 235, 49, 39, 34, 107, 111>>
  end
end
