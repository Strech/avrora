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

    test "when payload has null values, they are decoded as nil" do
      {:ok, decoded} = Codec.Plain.decode(null_payment_message(), schema: payment_schema())

      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => nil}
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

    test "when payload with null value is matching the schema and schema is usable" do
      {:ok, encoded} = Codec.Plain.encode(null_payment_payload(), schema: payment_schema())
      assert encoded == null_payment_message()
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

  defp null_payment_payload,
    do: %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => nil}

  defp payment_schema do
    {:ok, schema} = Schema.parse(payment_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp payment_json_schema do
    ~s({"namespace":"io.confluent","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":["null","double"]}]})
  end

  defp payment_message do
    <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48,
      48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 2, 123, 20, 174, 71, 225, 250, 47,
      64>>
  end

  defp null_payment_message do
    <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48,
      48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 0>>
  end
end
