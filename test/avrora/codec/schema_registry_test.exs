defmodule Avrora.Codec.SchemaRegistryTest do
  use ExUnit.Case, async: true
  doctest Avrora.Codec.SchemaRegistry

  import Mox
  import Support.Config

  alias Avrora.{Codec, Schema, Storage}

  setup :verify_on_exit!
  setup :support_config

  describe "decodable?/1" do
    test "when payload is a valid binary" do
      assert Codec.SchemaRegistry.decodable?(payment_message())
    end

    test "when payload is not a valid binary" do
      assert Codec.SchemaRegistry.decodable?(<<0, 1, 2>>)
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

  # describe "decode/2" do
  #   test "when payload is a valid binary and schema is not given" do
  #     assert Codec.Plain.decode(payment_message()) == {:error, :schema_required}
  #   end

  #   test "when payload is not a valid binary and schema is not given" do
  #     assert Codec.Plain.decode(<<0, 1, 2>>) == {:error, :schema_required}
  #   end

  #   test "when payload is a valid binary and schema is given" do
  #     {:ok, decoded} = Codec.Plain.decode(payment_message(), schema: payment_schema())

  #     assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
  #   end

  #   test "when payload is not a valid binary and schema is given" do
  #     assert Codec.Plain.decode(<<0, 1, 2>>, schema: payment_schema()) ==
  #              {:error, :schema_mismatch}
  #   end
  # end

  # describe "encode/2" do
  #   test "when payload is not matching the schema" do
  #     assert Codec.Plain.encode(%{"hello" => "world"}, schema: payment_schema()) ==
  #              {:error, missing_field_error()}
  #   end

  #   test "when payload is matching the schema" do
  #     {:ok, encoded} =
  #       Codec.Plain.encode(
  #         %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99},
  #         schema: payment_schema()
  #       )

  #     assert encoded == payment_message()
  #   end
  # end

  defp missing_field_error do
    %ErlangError{
      original:
        {:"$avro_encode_error", :required_field_missed,
         [record: "io.confluent.Payment", field: "id"]}
    }
  end

  defp payment_schema_with_id do
    {:ok, schema} = Schema.parse(payment_json_schema())
    %{schema | id: 42, version: nil}
  end

  defp payment_json_schema do
    ~s({"namespace":"io.confluent","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end

  defp payment_message do
    <<0, 0, 0, 0, 42, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48,
      45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71,
      225, 250, 47, 64>>
  end
end
