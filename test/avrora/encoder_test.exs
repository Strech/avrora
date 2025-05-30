defmodule Avrora.EncoderTest do
  use ExUnit.Case, async: true
  doctest Avrora.Encoder

  import Mox
  import Support.Config
  import ExUnit.CaptureLog
  alias Avrora.{Encoder, Schema}

  setup :verify_on_exit!
  setup :support_config

  describe "extract_schema/1" do
    test "when payload was encoded with schema registry magic byte" do
      payment_schema_with_id = payment_schema_with_id()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert payment_schema_with_id == value

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, payment_schema_with_id}
      end)

      {:ok, schema} = Encoder.extract_schema(payment_registry_message())

      assert schema.id == 42
      assert schema.full_name == "io.acme.Payment"
      assert schema.json == payment_json_schema()
    end

    test "when payload was encoded with OCF magic byte" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Payment"
        assert value.json == payment_json_schema()

        {:ok, value}
      end)

      {:ok, schema} = Encoder.extract_schema(payment_ocf_message())

      assert is_nil(schema.id)
      assert is_nil(schema.version)

      assert schema.full_name == "io.acme.Payment"
      assert schema.json == payment_json_schema()
    end

    test "when payload was encoded with no magic bytes" do
      assert Encoder.extract_schema(messenger_plain_message()) == {:error, :schema_not_found}
    end
  end

  describe "decode/1" do
    test "when payload was encoded with schema registry magic byte" do
      payment_schema_with_id = payment_schema_with_id()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == payment_schema_with_id

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, payment_schema_with_id}
      end)

      {:ok, decoded} = Encoder.decode(payment_registry_message())
      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload was encoded with OCF magic byte" do
      {:ok, decoded} = Encoder.decode(payment_ocf_message())
      assert decoded == [%{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}]
    end

    test "when payload was encoded with no magic bytes" do
      assert Encoder.decode(payment_plain_message()) == {:error, :schema_required}
    end
  end

  describe "decode/2" do
    test "when payload contains no magic byte and registry is not configured it uses local schema file" do
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

      {:ok, decoded} = Encoder.decode(payment_plain_message(), schema_name: "io.acme.Payment")

      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload contains no magic byte and registry is configured it registers local schema file" do
      payment_schema_with_id = payment_schema_with_id()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == payment_schema_with_id

        {:ok, value}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Payment"
        assert value == payment_schema_with_id

        {:ok, value}
      end)
      |> expect(:expire, fn key, ttl ->
        assert key == "io.acme.Payment"
        assert ttl == :infinity

        {:ok, :infinity}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, payment_schema()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Payment"
        assert value == payment_json_schema()

        {:ok, payment_schema_with_id}
      end)

      {:ok, decoded} = Encoder.decode(payment_plain_message(), schema_name: "io.acme.Payment")

      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload contains magic byte and registry is not configured it uses local schema file" do
      payment_schema = payment_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, nil}
      end)
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
      |> expect(:get, fn key ->
        assert key == 42

        {:error, :unconfigured_registry_url}
      end)
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

      {:ok, decoded} = Encoder.decode(payment_registry_message(), schema_name: "io.acme.Payment")

      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when given schema_name contains version it warns about it" do
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

      output =
        capture_log(fn ->
          {:ok, decoded} = Encoder.decode(payment_plain_message(), schema_name: "io.acme.Payment:42")

          assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
        end)

      assert output =~ "with schema version is not supported"
    end

    test "when payload is OCF and given schema_name it warn about enbeded schema" do
      output =
        capture_log(fn ->
          {:ok, decoded} = Encoder.decode(payment_ocf_message(), schema_name: "io.acme.Payment")

          assert decoded == [%{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}]
        end)

      assert output =~ "message already contains embeded schema, given schema will be ignored"
    end

    test "when payload contains type references it resolves them and generates new schema" do
      messenger_schema = messenger_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Messenger"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Messenger"
        assert value == messenger_schema

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Messenger"
        assert value == messenger_json_schema_with_local_reference()

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Messenger"

        {:ok, messenger_schema}
      end)

      {:ok, decoded} = Encoder.decode(messenger_plain_message(), schema_name: "io.acme.Messenger")

      assert decoded == %{
               "inbox" => [%{"text" => "Hello world!"}],
               "archive" => [%{"text" => "How are you?"}]
             }
    end
  end

  describe "decode_plain/2" do
    test "when decoding plain message that starts with what looks like a magic byte" do
      numeric_transfer_schema = numeric_transfer_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.NumericTransfer"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.acme.NumericTransfer"
        assert value == numeric_transfer_schema

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.acme.NumericTransfer"
        assert value == numeric_transfer_json_schema()

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.acme.NumericTransfer"

        {:ok, numeric_transfer_schema}
      end)

      {:ok, decoded} =
        Avrora.decode_plain(
          numeric_transfer_plain_message_with_fake_magic_byte(),
          schema_name: "io.acme.NumericTransfer"
        )

      assert decoded == numeric_transfer_payload()
    end
  end

  describe "encode/2" do
    test "when registry is not configured it uses local schema file" do
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
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, payment_schema}
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

      {:ok, encoded} = Encoder.encode(payment_payload(), schema_name: "io.acme.Payment")
      assert payment_ocf?(encoded)
    end

    test "when registry is not configured, but format requires schema id" do
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

      encoded = Encoder.encode(payment_payload(), schema_name: "io.acme.Payment", format: :registry)

      assert encoded == {:error, :invalid_schema_id}
    end

    test "when registry is configured and schema is found, but format is given explicitly" do
      payment_schema_with_id = payment_schema_with_id()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == payment_schema_with_id

        {:ok, value}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Payment"
        assert value == payment_schema_with_id

        {:ok, value}
      end)
      |> expect(:expire, fn key, ttl ->
        assert key == "io.acme.Payment"
        assert ttl == :infinity

        {:ok, :infinity}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, payment_schema()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Payment"
        assert value == payment_json_schema()

        {:ok, payment_schema_with_id}
      end)

      {:ok, encoded} = Encoder.encode(payment_payload(), schema_name: "io.acme.Payment", format: :ocf)

      assert payment_ocf?(encoded)
    end

    test "when registry is configured and schema not found (same as found)" do
      payment_schema_with_id = payment_schema_with_id()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == payment_schema_with_id

        {:ok, value}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Payment"
        assert value == payment_schema_with_id

        {:ok, value}
      end)
      |> expect(:expire, fn key, ttl ->
        assert key == "io.acme.Payment"
        assert ttl == :infinity

        {:ok, :infinity}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Payment"
        assert value == payment_json_schema()

        {:ok, payment_schema_with_id}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Payment"

        {:ok, payment_schema()}
      end)

      {:ok, encoded} = Encoder.encode(payment_payload(), schema_name: "io.acme.Payment")
      assert encoded == payment_registry_message()
    end

    test "when given schema_name contains version it warns about it" do
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

      output =
        capture_log(fn ->
          {:ok, encoded} =
            Encoder.encode(
              payment_payload(),
              schema_name: "io.acme.Payment:42",
              format: :plain
            )

          assert encoded == payment_plain_message()
        end)

      assert output =~ "with schema version is not supported"
    end

    test "when payload contains type references it resolves them and generates new schema" do
      messenger_schema = messenger_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Messenger"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Messenger"
        assert value == messenger_schema

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Messenger"
        assert value == messenger_json_schema_with_local_reference()

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Messenger"

        {:ok, messenger_schema}
      end)

      {:ok, encoded} = Encoder.encode(messenger_payload(), schema_name: "io.acme.Messenger", format: :plain)

      assert encoded == messenger_plain_message()
    end

    test "when `format` passed before `schema_name` option it accepts the order" do
      messenger_schema = messenger_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Messenger"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Messenger"
        assert value == messenger_schema

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.acme.Messenger"
        assert value == messenger_json_schema_with_local_reference()

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.acme.Messenger"

        {:ok, messenger_schema}
      end)

      {:ok, encoded} = Encoder.encode(messenger_payload(), format: :plain, schema_name: "io.acme.Messenger")

      assert encoded == messenger_plain_message()
    end
  end

  describe "encode_plain/2" do
    test "when encoded message will contain fake magic byte" do
      numeric_transfer_schema = numeric_transfer_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.acme.NumericTransfer"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.acme.NumericTransfer"
        assert value == numeric_transfer_schema

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.acme.NumericTransfer"
        assert value == numeric_transfer_json_schema()

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.acme.NumericTransfer"

        {:ok, numeric_transfer_schema}
      end)

      output =
        capture_log(fn ->
          {:ok, encoded} =
            Avrora.encode_plain(
              numeric_transfer_payload(),
              schema_name: "io.acme.NumericTransfer:1"
            )

          assert encoded == numeric_transfer_plain_message_with_fake_magic_byte()
        end)

      assert output =~ "with schema version is not supported"
    end
  end

  # byte_size(<< message container binary >>) * 8
  defp payment_ocf?(payload) do
    match?(
      <<79, 98, 106, 1, _::size(1464), 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45,
        48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64,
        _::binary>>,
      payload
    )
  end

  defp payment_payload, do: %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}

  defp messenger_payload,
    do: %{"inbox" => [%{"text" => "Hello world!"}], "archive" => [%{"text" => "How are you?"}]}

  defp numeric_transfer_payload,
    do: %{"link_is_enabled" => false, "updated_at" => 1_586_632_500, "updated_by_id" => 1_00}

  defp payment_registry_message do
    <<0, 0, 0, 0, 42, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48,
      45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
  end

  defp payment_ocf_message do
    <<79, 98, 106, 1, 3, 194, 2, 20, 97, 118, 114, 111, 46, 99, 111, 100, 101, 99, 8, 110, 117, 108, 108, 22, 97, 118,
      114, 111, 46, 115, 99, 104, 101, 109, 97, 134, 2, 123, 34, 110, 97, 109, 101, 115, 112, 97, 99, 101, 34, 58, 34,
      105, 111, 46, 97, 99, 109, 101, 34, 44, 34, 110, 97, 109, 101, 34, 58, 34, 80, 97, 121, 109, 101, 110, 116, 34,
      44, 34, 116, 121, 112, 101, 34, 58, 34, 114, 101, 99, 111, 114, 100, 34, 44, 34, 102, 105, 101, 108, 100, 115, 34,
      58, 91, 123, 34, 110, 97, 109, 101, 34, 58, 34, 105, 100, 34, 44, 34, 116, 121, 112, 101, 34, 58, 34, 115, 116,
      114, 105, 110, 103, 34, 125, 44, 123, 34, 110, 97, 109, 101, 34, 58, 34, 97, 109, 111, 117, 110, 116, 34, 44, 34,
      116, 121, 112, 101, 34, 58, 34, 100, 111, 117, 98, 108, 101, 34, 125, 93, 125, 0, 76, 217, 232, 193, 27, 233, 50,
      40, 75, 196, 233, 176, 94, 69, 45, 227, 2, 90, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48,
      48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47,
      64, 76, 217, 232, 193, 27, 233, 50, 40, 75, 196, 233, 176, 94, 69, 45, 227>>
  end

  defp payment_plain_message do
    <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48,
      48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
  end

  defp messenger_plain_message do
    <<1, 26, 24, 72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100, 33, 0, 1, 26, 24, 72, 111, 119, 32, 97, 114, 101,
      32, 121, 111, 117, 63, 0>>
  end

  defp numeric_transfer_plain_message_with_fake_magic_byte do
    <<0, 232, 220, 144, 233, 11, 200, 1>>
  end

  defp payment_schema do
    {:ok, schema} = Schema.Encoder.from_json(payment_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp payment_schema_with_id do
    {:ok, schema} = Schema.Encoder.from_json(payment_json_schema())
    %{schema | id: 42, version: nil}
  end

  defp messenger_schema do
    {:ok, schema} = Schema.Encoder.from_json(messenger_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp numeric_transfer_schema do
    {:ok, schema} = Schema.Encoder.from_json(numeric_transfer_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp messenger_json_schema do
    ~s({"namespace":"io.acme","name":"Messenger","type":"record","fields":[{"name":"inbox","type":{"type":"array","items":{"type":"record","name":"Message","fields":[{"name":"text","type":"string"}]}}},{"name":"archive","type":{"type":"array","items":"io.acme.Message"}}]})
  end

  defp messenger_json_schema_with_local_reference do
    ~s({"namespace":"io.acme","name":"Messenger","type":"record","fields":[{"name":"inbox","type":{"type":"array","items":{"name":"Message","type":"record","fields":[{"name":"text","type":"string"}]}}},{"name":"archive","type":{"type":"array","items":"Message"}}]})
  end

  defp payment_json_schema do
    ~s({"namespace":"io.acme","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end

  defp numeric_transfer_json_schema do
    ~s({"namespace":"io.acme","name":"NumericTransfer","type":"record","fields":[{"name":"link_is_enabled","type":"boolean"},{"name":"updated_at","type":"int"},{"name":"updated_by_id","type":"int"}]})
  end
end
