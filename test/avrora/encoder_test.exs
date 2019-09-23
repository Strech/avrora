defmodule Avrora.EncoderTest do
  use ExUnit.Case, async: true
  doctest Avrora.Encoder

  import Mox
  import ExUnit.CaptureLog
  alias Avrora.{Encoder, Schema}

  setup :verify_on_exit!

  describe "decode/1" do
    test "when payload was encoded with OCF magic byte" do
      {:ok, decoded} = Encoder.decode(payment_ocf_message())
      assert decoded == [%{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}]
    end

    test "when payload was encoded with magic byte and registry is configured" do
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

    test "when payload was encoded with magic byte and registry is not configured" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, nil}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:error, :unconfigured_registry_url}
      end)

      assert {:error, :unconfigured_registry_url} = Encoder.decode(payment_registry_message())
    end

    test "when payload was encoded with no magic bytes" do
      assert {:error, :undecodable} = Encoder.decode(payment_plain_message())
    end
  end

  describe "decode/2" do
    test "when payload was encoded without magic byte and registry is not configured" do
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
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema}
      end)

      {:ok, decoded} =
        Encoder.decode(payment_plain_message(), schema_name: "io.confluent.Payment")

      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload was encoded without magic byte and registry is configured" do
      payment_payment_schema_with_id_and_version = payment_payment_schema_with_id_and_version()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment:3"
        assert value == payment_payment_schema_with_id_and_version

        {:ok, value}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_payment_schema_with_id_and_version

        {:ok, value}
      end)
      |> expect(:expire, fn key, ttl ->
        assert key == "io.confluent.Payment"
        assert ttl == :infinity

        {:ok, :infinity}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == payment_payment_schema_with_id_and_version

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_payment_schema_with_id_and_version}
      end)

      {:ok, decoded} =
        Encoder.decode(payment_plain_message(), schema_name: "io.confluent.Payment")

      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload was encoded with magic byte and registry is not configured" do
      payment_schema = payment_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, nil}
      end)

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
      |> expect(:get, fn key ->
        assert key == 42

        {:error, :unconfigured_registry_url}
      end)
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema}
      end)

      {:ok, decoded} =
        Encoder.decode(payment_registry_message(), schema_name: "io.confluent.Payment")

      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload was encoded with magic byte and registry is configured" do
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

      output =
        capture_log(fn ->
          {:ok, decoded} =
            Encoder.decode(payment_registry_message(), schema_name: "io.confluent.Payment")

          assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
        end)

      assert output =~ "message contains embeded global id, given schema name will be ignored"
    end

    test "when decoding with schema name containing version" do
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
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema}
      end)

      output =
        capture_log(fn ->
          {:ok, decoded} =
            Encoder.decode(payment_plain_message(), schema_name: "io.confluent.Payment:42")

          assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
        end)

      assert output =~ "with schema version is not supported"
    end

    test "when decoding with schema name OCF message" do
      output =
        capture_log(fn ->
          {:ok, decoded} =
            Encoder.decode(payment_ocf_message(), schema_name: "io.confluent.Payment")

          assert decoded == [%{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}]
        end)

      assert output =~ "given schema name will be ignored"
    end

    test "when decoding plain message with type reference in it" do
      messenger_schema = messenger_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Messenger"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Messenger"
        assert value == messenger_schema

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Messenger"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Messenger"

        {:ok, messenger_schema}
      end)

      {:ok, decoded} =
        Encoder.decode(messenger_plain_message(), schema_name: "io.confluent.Messenger")

      assert decoded == %{
               "inbox" => [%{"text" => "Hello world!"}],
               "archive" => [%{"text" => "How are you?"}]
             }
    end
  end

  describe "encode/2" do
    test "when registry is not configured" do
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
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema}
      end)

      {:ok, encoded} = Encoder.encode(payment_payload(), schema_name: "io.confluent.Payment")
      assert is_payment_ocf(encoded)
    end

    test "when registry is not configured, but format requires schema version" do
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
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema}
      end)

      result =
        Encoder.encode(payment_payload(), schema_name: "io.confluent.Payment", format: :registry)

      assert {:error, :invalid_schema_id} = result
    end

    test "when registry is configured and schema is found, but format is given explicitly" do
      payment_payment_schema_with_id_and_version = payment_payment_schema_with_id_and_version()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment:3"
        assert value == payment_payment_schema_with_id_and_version

        {:ok, value}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_payment_schema_with_id_and_version

        {:ok, value}
      end)
      |> expect(:expire, fn key, ttl ->
        assert key == "io.confluent.Payment"
        assert ttl == :infinity

        {:ok, :infinity}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == payment_payment_schema_with_id_and_version

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_payment_schema_with_id_and_version}
      end)

      {:ok, encoded} =
        Encoder.encode(payment_payload(), schema_name: "io.confluent.Payment", format: :ocf)

      assert is_payment_ocf(encoded)
    end

    test "when registry is configured, but schema not found" do
      payment_schema_with_id = payment_schema_with_id()
      payment_schema = payment_schema()

      Avrora.Storage.MemoryMock
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
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == payment_schema_with_id

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unknown_subject}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_json_schema()

        {:ok, payment_schema_with_id}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema}
      end)

      {:ok, encoded} = Encoder.encode(payment_payload(), schema_name: "io.confluent.Payment")
      assert payment_registry_message() == encoded
    end

    test "when registry is configured and schema was found" do
      payment_payment_schema_with_id_and_version = payment_payment_schema_with_id_and_version()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment:3"
        assert value == payment_payment_schema_with_id_and_version

        {:ok, value}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_payment_schema_with_id_and_version

        {:ok, value}
      end)
      |> expect(:expire, fn key, ttl ->
        assert key == "io.confluent.Payment"
        assert ttl == :infinity

        {:ok, :infinity}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == payment_payment_schema_with_id_and_version

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_payment_schema_with_id_and_version}
      end)

      {:ok, encoded} = Encoder.encode(payment_payload(), schema_name: "io.confluent.Payment")
      assert payment_registry_message() == encoded
    end

    test "when schema name provided with version" do
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
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema}
      end)

      output =
        capture_log(fn ->
          {:ok, encoded} =
            Encoder.encode(payment_payload(),
              schema_name: "io.confluent.Payment:42",
              format: :plain
            )

          assert payment_plain_message() == encoded
        end)

      assert output =~ "with schema version is not supported"
    end

    test "when registry is not configured and payload contains type reference" do
      messenger_schema = messenger_schema()

      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Messenger"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Messenger"
        assert value == messenger_schema

        {:ok, value}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Messenger"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Messenger"

        {:ok, messenger_schema}
      end)

      {:ok, encoded} =
        Encoder.encode(messenger_payload(), schema_name: "io.confluent.Messenger", format: :plain)

      assert encoded == messenger_plain_message()
    end
  end

  defp is_payment_ocf(payload) do
    match?(
      <<79, 98, 106, 1, _::size(1504), 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45,
        48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48,
        123, 20, 174, 71, 225, 250, 47, 64, _::binary>>,
      payload
    )
  end

  defp payment_payload, do: %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}

  defp messenger_payload,
    do: %{"inbox" => [%{"text" => "Hello world!"}], "archive" => [%{"text" => "How are you?"}]}

  defp payment_registry_message do
    <<0, 0, 0, 0, 42, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48,
      45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71,
      225, 250, 47, 64>>
  end

  defp payment_ocf_message do
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

  defp payment_plain_message do
    <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48,
      48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
  end

  defp messenger_plain_message do
    <<1, 26, 24, 72, 101, 108, 108, 111, 32, 119, 111, 114, 108, 100, 33, 0, 1, 26, 24, 72, 111,
      119, 32, 97, 114, 101, 32, 121, 111, 117, 63, 0>>
  end

  defp payment_schema do
    {:ok, schema} = Schema.parse(payment_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp payment_payment_schema_with_id_and_version do
    {:ok, schema} = Schema.parse(payment_json_schema())
    %{schema | id: 42, version: 3}
  end

  defp payment_schema_with_id do
    {:ok, schema} = Schema.parse(payment_json_schema())
    %{schema | id: 42, version: nil}
  end

  defp messenger_schema do
    {:ok, schema} = Schema.parse(messenger_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp messenger_json_schema do
    ~s({"type":"record","name":"Messenger","namespace":"io.confluent","fields":[{"name":"inbox","type":{"type":"array","items":{"type":"record","name":"Message","fields":[{"name":"text","type":"string"}]}}},{"name":"archive","type":{"type":"array","items":"io.confluent.Message"}}]})
  end

  defp payment_json_schema do
    ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end
end
