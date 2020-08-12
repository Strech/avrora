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
      assert Codec.Plain.decodable?(payment_plain_message())
    end

    test "when payload is not a valid binary" do
      assert Codec.Plain.decodable?(<<0, 1, 2>>)
    end
  end

  describe "extract_schema/1" do
    test "when payload is a valid binary" do
      assert Codec.Plain.extract_schema(payment_plain_message()) == {:error, :schema_not_found}
    end
  end

  describe "decode/2" do
    test "when payload is a valid binary and schema is not given" do
      assert Codec.Plain.decode(payment_plain_message()) == {:error, :schema_required}
    end

    test "when payload is not a valid binary and schema is not given" do
      assert Codec.Plain.decode(<<0, 1, 2>>) == {:error, :schema_required}
    end

    test "when payload is a valid binary and schema is given" do
      {:ok, decoded} = Codec.Plain.decode(payment_plain_message(), schema: payment_schema())

      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload is not a valid binary and schema is given" do
      assert Codec.Plain.decode(<<0, 1, 2>>, schema: payment_schema()) ==
               {:error, :undecodable}
    end
  end

  describe "encode/2" do
    test "when payload is not matching the schema" do
      assert Codec.Plain.encode(%{"hello" => "world"}, schema: payment_schema()) ==
               {:error,
                %ErlangError{
                  original:
                    {:"$avro_encode_error", :required_field_missed,
                     [record: "io.confluent.Payment", field: "id"]}
                }}
    end

    test "when payload is matching the schema" do
      {:ok, encoded} =
        Codec.Plain.encode(
          %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99},
          schema: payment_schema()
        )

      assert encoded == payment_plain_message()
    end
  end

  defp payment_schema do
    {:ok, schema} = Schema.parse(payment_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp payment_json_schema do
    ~s({"namespace":"io.confluent","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end

  defp payment_plain_message do
    <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48,
      48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
  end
end
