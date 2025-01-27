defmodule Avrora.Codec.PlainTest do
  use ExUnit.Case, async: true
  doctest Avrora.Codec.Plain

  import Mox
  import Support.Config

  alias Avrora.{Codec, Schema}

  setup :verify_on_exit!
  setup :support_config

  describe "decodable?/1" do
    test "when payload is a valid binary" do
      assert Codec.Plain.decodable?(payment_message())
    end

    test "when payload is not a valid binary" do
      assert Codec.Plain.decodable?(<<0, 1, 2>>)
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
        assert value == payment_json()

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, payment_schema}
      end)

      {:ok, decoded} = Codec.Plain.decode(payment_message(), schema: %Schema{full_name: "io.acme.Payment"})

      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload is a valid binary and null values must be as is" do
      stub(Avrora.ConfigMock, :convert_null_values, fn -> false end)

      {:ok, decoded} = Codec.Plain.decode(null_value_message(), schema: record_with_null_union_field_schema())

      assert decoded == %{"key" => "user-1", "value" => :null}
    end

    test "when payload is a valid binary and null values must be converted" do
      {:ok, decoded} = Codec.Plain.decode(null_value_message(), schema: record_with_null_union_field_schema())

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
      assert Codec.Plain.decode(payment_message(), schema: %Schema{}) == {:error, :unusable_schema}
    end

    test "when payload is not a valid binary and schema is usable" do
      assert Codec.Plain.decode(<<0, 1, 2>>, schema: payment_schema()) == {:error, :schema_mismatch}
    end

    test "when payload is valid binary and union type must be decoded without decoding hook" do
      {:ok, decoded_int} = Codec.Plain.decode(<<2, 84>>, schema: record_with_record_union_field_schema())
      {:ok, decoded_str} = Codec.Plain.decode(<<0, 4, 52, 50>>, schema: record_with_record_union_field_schema())

      assert decoded_int == %{"union_field" => %{"value" => 42}}
      assert decoded_str == %{"union_field" => %{"value" => "42"}}
    end

    test "when decoding message with union and with tagged union hook" do
      stub(Avrora.ConfigMock, :decoder_hook, fn ->
        fn type, sub_name_or_index, data, decode_fun ->
          hook = :avro_decoder_hooks.tag_unions()
          hook.(type, sub_name_or_index, data, decode_fun)
        end
      end)

      {:ok, decoded_int} = Codec.Plain.decode(<<2, 84>>, schema: record_with_record_union_field_schema())
      {:ok, decoded_str} = Codec.Plain.decode(<<0, 4, 52, 50>>, schema: record_with_record_union_field_schema())

      assert decoded_int == %{"union_field" => {"io.acme.as_int", %{"value" => 42}}}
      assert decoded_str == %{"union_field" => {"io.acme.as_str", %{"value" => "42"}}}
    end
  end

  describe "encode/2" do
    test "when payload is not matching the schema" do
      assert Codec.Plain.encode(%{"hello" => "world"}, schema: payment_schema()) == {:error, missing_field_error()}
    end

    test "when payload is matching the schema and schema is unusable" do
      assert Codec.Plain.encode(payment_payload(), schema: %Schema{}) == {:error, :unusable_schema}
    end

    test "when payload is matching the schema and schema is usable" do
      {:ok, encoded} = Codec.Plain.encode(payment_payload(), schema: payment_schema())

      assert encoded == payment_message()
    end

    test "when payload is matching the Record schema and schema is resolvable" do
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
        assert value == payment_json()

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, payment_schema}
      end)

      {:ok, encoded} = Codec.Plain.encode(payment_payload(), schema: %Schema{full_name: "io.acme.Payment"})

      assert encoded == payment_message()
    end

    test "when payload is matching the Enum schema and schema is resolvable" do
      enum_schema = enum_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.CardType"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.acme.CardType"
        assert value == enum_schema

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.acme.CardType"
        assert value == enum_json()

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.acme.CardType"

        {:ok, enum_schema}
      end)

      {:ok, encoded} = Codec.Plain.encode("VISA", schema: %Schema{full_name: "io.acme.CardType"})

      assert encoded == <<2>>
    end

    test "when payload is matching the Fixed schema and schema is resolvable" do
      fixed_schema = fixed_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.CRC32"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.acme.CRC32"
        assert value == fixed_schema

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.acme.CRC32"
        assert value == fixed_json()

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.acme.CRC32"

        {:ok, fixed_schema}
      end)

      {:ok, encoded} = Codec.Plain.encode("59B02128", schema: %Schema{full_name: "io.acme.CRC32"})

      assert encoded == "59B02128"
    end
  end

  defp missing_field_error do
    %ErlangError{
      original: {:"$avro_encode_error", :required_field_missed, [record: "io.acme.Payment", field: "id"]}
    }
  end

  defp payment_message do
    <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48,
      48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
  end

  defp null_value_message, do: <<12, 117, 115, 101, 114, 45, 49, 0>>
  defp map_message, do: <<1, 20, 6, 107, 101, 121, 10, 118, 97, 108, 117, 101, 0>>
  defp payment_payload, do: %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}

  defp payment_schema do
    {:ok, schema} = Schema.Encoder.from_json(payment_json())
    %{schema | id: nil, version: nil}
  end

  defp record_with_null_union_field_schema do
    {:ok, schema} = Schema.Encoder.from_json(record_with_null_union_field_json())
    %{schema | id: nil, version: nil}
  end

  defp record_with_record_union_field_schema do
    {:ok, schema} = Schema.Encoder.from_json(record_with_record_union_field_json())
    %{schema | id: nil, version: nil}
  end

  defp map_schema do
    {:ok, schema} = Schema.Encoder.from_json(record_with_map_field_json())
    %{schema | id: nil, version: nil}
  end

  defp enum_schema do
    {:ok, schema} = Schema.Encoder.from_json(enum_json())
    %{schema | id: nil, version: nil}
  end

  defp fixed_schema do
    {:ok, schema} = Schema.Encoder.from_json(fixed_json())
    %{schema | id: nil, version: nil}
  end

  defp payment_json do
    ~s({"namespace":"io.acme","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end

  defp record_with_null_union_field_json do
    ~s({"namespace":"io.acme","name":"NullValue","type":"record","fields":[{"name":"key","type":"string"},{"name":"value","type":["null","int"]}]})
  end

  defp record_with_record_union_field_json do
    ~s({"namespace":"io.acme","name":"UnionValue","type":"record","fields":[{"name":"union_field","type":[{"type":"record","name":"as_str","fields":[{"name":"value","type":"string"}]},{"type":"record","name":"as_int","fields":[{"name":"value","type":"int"}]}]}]})
  end

  defp record_with_map_field_json do
    ~s({"namespace":"io.acme","name":"MapValue","type":"record","fields":[{"name":"map_field", "type": {"type": "map", "values": "string"}}]})
  end

  defp enum_json do
    ~s({"namespace":"io.acme","name":"CardType","type":"enum","symbols":["MASTERCARD","VISA","AMERICANEXPRESS"]})
  end

  defp fixed_json do
    ~s({"namespace":"io.acme","name":"CRC32","type":"fixed","size":8})
  end
end
