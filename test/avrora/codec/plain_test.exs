defmodule Avrora.Codec.PlainTest do
  use ExUnit.Case, async: true
  doctest Avrora.Codec.Plain

  import Mox
  import Support.Config

  alias Avrora.{Codec, Schema}

  setup :verify_on_exit!
  setup :support_config

  describe "is_decodable/1" do
    test "when payload is a valid binary" do
      assert Codec.Plain.is_decodable(payment_message())
    end

    test "when payload is not a valid binary" do
      assert Codec.Plain.is_decodable(<<0, 1, 2>>)
    end
  end

  describe "extract_schema/1" do
    test "when payload is a valid binary" do
      assert Codec.Plain.extract_schema(payment_message()) == {:error, :schema_not_found}
    end
  end

  describe "decode/2" do
    test "when payload is a valid binary and schema is not given" do
      assert Codec.Plain.decode(payment_message()) == {:error, :schema_required}
    end

    test "when payload is not a valid binary and schema is not given" do
      assert Codec.Plain.decode(<<0, 1, 2>>) == {:error, :schema_required}
    end

    test "when payload is a valid binary and schema is usable" do
      {:ok, decoded} = Codec.Plain.decode(payment_message(), schema: payment_schema())

      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload is a valid binary and schema is resolvable" do
      payment_schema = payment_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_schema

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_json_schema()

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema}
      end)

      {:ok, decoded} =
        Codec.Plain.decode(payment_message(), schema: %Schema{full_name: "io.confluent.Payment"})

      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload is a valid binary and null values must be as is" do
      stub(Avrora.ConfigMock, :convert_null_values, fn -> false end)

      {:ok, decoded} = Codec.Plain.decode(null_value_message(), schema: null_value_schema())

      assert decoded == %{"key" => "user-1", "value" => :null}
    end

    test "when payload is a valid binary and null values must be converted" do
      {:ok, decoded} = Codec.Plain.decode(null_value_message(), schema: null_value_schema())

      assert decoded == %{"key" => "user-1", "value" => nil}
    end

    test "when payload is a valid binary and map type must be decoded as proplist" do
      stub(Avrora.ConfigMock, :convert_map_to_proplist, fn -> true end)

      {:ok, decoded} = Codec.Plain.decode(map_message(), schema: map_schema())

      assert decoded == %{"map_field" => [{"key", "value"}]}
    end

    test "when payload is a valid binary and map type must be decoded as map" do
      {:ok, decoded} = Codec.Plain.decode(map_message(), schema: map_schema())

      assert decoded == %{"map_field" => %{"key" => "value"}}
    end

    test "when payload is a valid binary and schema is unusable" do
      assert Codec.Plain.decode(payment_message(), schema: %Schema{}) ==
               {:error, :unusable_schema}
    end

    test "when payload is not a valid binary and schema is usable" do
      assert Codec.Plain.decode(<<0, 1, 2>>, schema: payment_schema()) ==
               {:error, :schema_mismatch}
    end
  end

  describe "encode/2" do
    test "when payload is not matching the schema" do
      assert Codec.Plain.encode(%{"hello" => "world"}, schema: payment_schema()) ==
               {:error, missing_field_error()}
    end

    test "when payload is matching the schema and schema is unusable" do
      assert Codec.Plain.encode(payment_payload(), schema: %Schema{}) ==
               {:error, :unusable_schema}
    end

    test "when payload is matching the schema and schema is usable" do
      {:ok, encoded} = Codec.Plain.encode(payment_payload(), schema: payment_schema())

      assert encoded == payment_message()
    end

    test "when payload is matching the schema and schema is resolvable" do
      payment_schema = payment_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_schema

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_json_schema()

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema}
      end)

      {:ok, encoded} =
        Codec.Plain.encode(payment_payload(), schema: %Schema{full_name: "io.confluent.Payment"})

      assert encoded == payment_message()
    end
  end

  defp missing_field_error do
    %ErlangError{
      original:
        {:"$avro_encode_error", :required_field_missed,
         [record: "io.confluent.Payment", field: "id"]}
    }
  end

  defp payment_payload, do: %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}

  defp payment_schema do
    {:ok, schema} = Schema.Codec.from_json(payment_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp null_value_schema do
    {:ok, schema} = Schema.Codec.from_json(null_value_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp map_schema do
    {:ok, schema} = Schema.Codec.from_json(map_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp payment_json_schema do
    ~s({"namespace":"io.confluent","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end

  defp null_value_json_schema do
    ~s({"namespace":"io.confluent","name":"Null_Value","type":"record","fields":[{"name":"key","type":"string"},{"name":"value","type":["null","int"]}]})
  end

  defp map_json_schema do
    ~s({"namespace":"io.confluent","name":"Map_Value","type":"record","fields":[{"name":"map_field", "type": {"type": "map", "values": "string"}}]})
  end

  defp payment_message do
    <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48,
      48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
  end

  defp null_value_message, do: <<12, 117, 115, 101, 114, 45, 49, 0>>

  defp map_message, do: <<1, 20, 6, 107, 101, 121, 10, 118, 97, 108, 117, 101, 0>>
end
