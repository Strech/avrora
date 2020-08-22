defmodule Avrora.Codec.ObjectContainerFileTest do
  use ExUnit.Case, async: true
  doctest Avrora.Codec.ObjectContainerFile

  import Mox
  import Support.Config
  import ExUnit.CaptureLog

  alias Avrora.{Codec, Schema}

  setup :verify_on_exit!
  setup :support_config

  describe "decodable?/1" do
    test "when payload is a valid binary" do
      assert Codec.ObjectContainerFile.decodable?(payment_message())
    end

    test "when payload is not a valid binary" do
      refute Codec.ObjectContainerFile.decodable?(<<0, 1, 2>>)
    end
  end

  describe "extract_schema/1" do
    test "when payload is valid and contain schema" do
      {:ok, schema} = Codec.ObjectContainerFile.extract_schema(payment_message())

      assert is_nil(schema.id)
      assert is_nil(schema.version)

      assert schema.full_name == "io.confluent.Payment"
      assert schema.json == payment_json_schema()
    end

    test "when payload is invalid" do
      assert Codec.ObjectContainerFile.extract_schema(<<79, 98, 106, 1, 0, 1, 2>>) ==
               {:error, :schema_mismatch}
    end
  end

  describe "decode/2" do
    test "when payload is a valid binary and schema is not given" do
      {:ok, decoded} = Codec.ObjectContainerFile.decode(payment_message())

      assert decoded == [%{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}]
    end

    test "when payload is not a valid binary and schema is not given" do
      assert Codec.ObjectContainerFile.decode(<<79, 98, 106, 1, 0, 1, 2>>) ==
               {:error, :schema_mismatch}
    end

    test "when payload is a valid binary and schema is given" do
      output =
        capture_log(fn ->
          {:ok, decoded} =
            Codec.ObjectContainerFile.decode(payment_message(), schema: payment_schema())

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

    test "when payload is matching the schema" do
      {:ok, encoded} =
        Codec.ObjectContainerFile.encode(
          %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99},
          schema: payment_schema()
        )

      assert is_payment_ocf(encoded)
    end
  end

  defp missing_field_error do
    %ErlangError{
      original:
        {:"$avro_encode_error", :required_field_missed,
         [record: "io.confluent.Payment", field: "id"]}
    }
  end

  defp is_payment_ocf(payload) do
    match?(
      <<79, 98, 106, 1, _::size(1504), 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45,
        48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48,
        123, 20, 174, 71, 225, 250, 47, 64, _::binary>>,
      payload
    )
  end

  defp payment_schema do
    {:ok, schema} = Schema.parse(payment_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp payment_json_schema do
    ~s({"namespace":"io.confluent","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
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
end
