defmodule Avrora.ObjectContainerFileTest do
  use ExUnit.Case, async: true
  doctest Avrora.ObjectContainerFile

  import Mox
  import Support.Config
  alias Avrora.{ObjectContainerFile, Schema}

  setup :verify_on_exit!
  setup :support_config

  describe "decode/1" do
    test "when message is malformed" do
      {status, message} = ObjectContainerFile.decode(<<0, 0, 1>>)

      assert status == :error
      assert message == %MatchError{term: <<0, 0, 1>>}
    end

    test "when message is valid" do
      {:ok, {headers, schema, decoded}} = ObjectContainerFile.decode(payment_message())
      {:header, _, [{"avro.codec", meta_codec}, {"avro.schema", meta_schema}], _} = headers

      assert meta_codec == "null"
      assert meta_schema == payment_json()
      assert schema == payment_erlavro()
      assert decoded == [[{"id", "00000000-0000-0000-0000-000000000000"}, {"amount", 15.99}]]
    end
  end

  describe "extract_schema/1" do
    test "when message is malformed" do
      {status, message} = ObjectContainerFile.extract_schema(<<0, 0, 1>>)

      assert status == :error
      assert message == %MatchError{term: <<0, 0, 1>>}
    end

    test "when message is valid and nothing found in memory" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value.json == payment_json()

        {:ok, value}
      end)

      {:ok, schema} = ObjectContainerFile.extract_schema(payment_message())

      assert is_nil(schema.id)
      assert is_nil(schema.version)
      assert is_reference(schema.lookup_table)

      assert schema.full_name == "io.confluent.Payment"
      assert schema.json == payment_json()
    end

    test "when message is valid and found in memory" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema()}
      end)

      {:ok, schema} = ObjectContainerFile.extract_schema(payment_message())

      assert is_nil(schema.id)
      assert is_nil(schema.version)
      assert is_reference(schema.lookup_table)

      assert schema.full_name == "io.confluent.Payment"
      assert schema.json == payment_json()
    end
  end

  defp payment_message do
    <<79, 98, 106, 1, 3, 204, 2, 20, 97, 118, 114, 111, 46, 99, 111, 100, 101, 99, 8, 110, 117,
      108, 108, 22, 97, 118, 114, 111, 46, 115, 99, 104, 101, 109, 97, 144, 2, 123, 34, 110, 97,
      109, 101, 115, 112, 97, 99, 101, 34, 58, 34, 105, 111, 46, 99, 111, 110, 102, 108, 117, 101,
      110, 116, 34, 44, 34, 110, 97, 109, 101, 34, 58, 34, 80, 97, 121, 109, 101, 110, 116, 34,
      44, 34, 116, 121, 112, 101, 34, 58, 34, 114, 101, 99, 111, 114, 100, 34, 44, 34, 102, 105,
      101, 108, 100, 115, 34, 58, 91, 123, 34, 110, 97, 109, 101, 34, 58, 34, 105, 100, 34, 44,
      34, 116, 121, 112, 101, 34, 58, 34, 115, 116, 114, 105, 110, 103, 34, 125, 44, 123, 34, 110,
      97, 109, 101, 34, 58, 34, 97, 109, 111, 117, 110, 116, 34, 44, 34, 116, 121, 112, 101, 34,
      58, 34, 100, 111, 117, 98, 108, 101, 34, 125, 93, 125, 0, 236, 47, 96, 164, 206, 59, 152,
      115, 80, 243, 64, 50, 180, 153, 105, 34, 2, 90, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48,
      48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48,
      48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64, 236, 47, 96, 164, 206, 59, 152, 115, 80,
      243, 64, 50, 180, 153, 105, 34>>
  end

  defp payment_erlavro do
    {:avro_record_type, "Payment", "io.confluent", "", [],
     [
       {:avro_record_field, "id", "", {:avro_primitive_type, "string", []}, :undefined,
        :ascending, []},
       {:avro_record_field, "amount", "", {:avro_primitive_type, "double", []}, :undefined,
        :ascending, []}
     ], "io.confluent.Payment", []}
  end

  defp payment_schema do
    Schema.parse(payment_json()) |> elem(1)
  end

  defp payment_json do
    ~s({"namespace":"io.confluent","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end
end
