defmodule Avrora.EncoderTest do
  use ExUnit.Case, async: true
  doctest Avrora.Encoder

  import Mox
  import ExUnit.CaptureLog
  alias Avrora.Encoder

  describe "decode/1" do
    test "when payload was encoded with OCF magic byte" do
      {:ok, decoded} = Encoder.decode(ocf_magic_message())
      assert decoded == [%{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}]
    end

    test "when payload was encoded with magic byte and registry is configured" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == 42
        assert value == schema_with_id()

        {:ok, schema_with_id()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == 42

        {:ok, schema_with_id()}
      end)

      {:ok, decoded} = Encoder.decode(magic_message())
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

      assert {:error, :unconfigured_registry_url} = Encoder.decode(magic_message())
    end

    test "when payload was encoded with no magic bytes" do
      assert {:error, :undecodable} = Encoder.decode(message())
    end
  end

  describe "decode/2" do
    test "when payload was encoded without magic byte and registry is not configured" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema()

        {:ok, schema()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema()}
      end)

      {:ok, decoded} = Encoder.decode(not_magic_message(), schema_name: "io.confluent.Payment")
      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload was encoded without magic byte and registry is configured" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema_with_version()

        {:ok, schema_with_version()}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment:42"
        assert value == schema_with_version()

        {:ok, schema_with_version()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema_with_version()}
      end)

      {:ok, decoded} = Encoder.decode(not_magic_message(), schema_name: "io.confluent.Payment")
      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload was encoded with magic byte and registry is not configured" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:42"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema()

        {:ok, schema()}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment:42"
        assert value == schema()

        {:ok, schema_with_version()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:42"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:42"

        {:ok, schema()}
      end)

      {:ok, decoded} = Encoder.decode(magic_message(), schema_name: "io.confluent.Payment")
      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when payload was encoded with magic byte and registry is configured" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:42"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema_with_version()

        {:ok, schema_with_version()}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment:42"
        assert value == schema_with_version()

        {:ok, schema_with_version()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment:42"

        {:ok, schema_with_version()}
      end)

      {:ok, decoded} = Encoder.decode(magic_message(), schema_name: "io.confluent.Payment")
      assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
    end

    test "when decoding with schema name containing version" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema()

        {:ok, schema()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema()}
      end)

      output =
        capture_log(fn ->
          {:ok, decoded} =
            Encoder.decode(not_magic_message(), schema_name: "io.confluent.Payment:42")

          assert decoded == %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}
        end)

      assert output =~ "with schema version is not allowed"
    end
  end

  describe "encode/2" do
    test "when registry is not configured" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema()

        {:ok, schema()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema()}
      end)

      {:ok, encoded} = Encoder.encode(raw_message(), schema_name: "io.confluent.Payment")
      assert not_magic_message() == encoded
    end

    test "when registry is configured, but schema not found" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema_with_version()

        {:ok, schema_with_version()}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment:42"
        assert value == schema_with_version()

        {:ok, schema_with_version()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unknown_subject}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == raw_schema()

        {:ok, schema_with_version()}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema()}
      end)

      {:ok, encoded} = Encoder.encode(raw_message(), schema_name: "io.confluent.Payment")
      assert magic_message() == encoded
    end

    test "when registry is configured and schema was found" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema_with_version()

        {:ok, schema_with_version()}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment:42"
        assert value == schema_with_version()

        {:ok, schema_with_version()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema_with_version()}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema()}
      end)

      {:ok, encoded} = Encoder.encode(raw_message(), schema_name: "io.confluent.Payment")
      assert magic_message() == encoded
    end

    test "when schema name provided with version" do
      Avrora.Storage.MemoryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, nil}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == schema()

        {:ok, schema()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:error, :unconfigured_registry_url}
      end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, schema()}
      end)

      output =
        capture_log(fn ->
          {:ok, encoded} = Encoder.encode(raw_message(), schema_name: "io.confluent.Payment:42")
          assert not_magic_message() == encoded
        end)

      assert output =~ "with schema version is not allowed"
    end
  end

  defp raw_message, do: %{"id" => "00000000-0000-0000-0000-000000000000", "amount" => 15.99}

  defp message do
    <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48,
      48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
  end

  defp magic_message do
    <<0, 0, 0, 0, 42, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48,
      45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71,
      225, 250, 47, 64>>
  end

  defp ocf_magic_message do
    <<79, 98, 106, 1, 3, 204, 2, 20, 97, 118, 114, 111, 46, 99, 111, 100, 101, 99, 8, 110, 117,
      108, 108, 22, 97, 118, 114, 111, 46, 115, 99, 104, 101, 109, 97, 144, 2, 123, 34, 110, 97,
      109, 101, 115, 112, 97, 99, 101, 34, 58, 34, 105, 111, 46, 99, 111, 110, 102, 108, 117, 101,
      110, 116, 34, 44, 34, 110, 97, 109, 101, 34, 58, 34, 80, 97, 121, 109, 101, 110, 116, 34,
      44, 34, 116, 121, 112, 101, 34, 58, 34, 114, 101, 99, 111, 114, 100, 34, 44, 34, 102, 105,
      101, 108, 100, 115, 34, 58, 91, 123, 34, 110, 97, 109, 101, 34, 58, 34, 105, 100, 34, 44,
      34, 116, 121, 112, 101, 34, 58, 34, 115, 116, 114, 105, 110, 103, 34, 125, 44, 123, 34, 110,
      97, 109, 101, 34, 58, 34, 97, 109, 111, 117, 110, 116, 34, 44, 34, 116, 121, 112, 101, 34,
      58, 34, 100, 111, 117, 98, 108, 101, 34, 125, 93, 125, 0, 50, 8, 86, 136, 188, 182, 153, 91,
      143, 129, 0, 45, 200, 112, 4, 192, 2, 90, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48,
      48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48,
      48, 48, 123, 20, 174, 71, 225, 250, 47, 64, 50, 8, 86, 136, 188, 182, 153, 91, 143, 129, 0,
      45, 200, 112, 4, 192>>
  end

  defp not_magic_message do
    <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48,
      48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
  end

  defp schema do
    %Avrora.Schema{
      id: nil,
      version: nil,
      schema: erlavro_schema(),
      raw_schema: raw_schema()
    }
  end

  defp schema_with_version do
    %Avrora.Schema{
      id: nil,
      version: 42,
      schema: erlavro_schema(),
      raw_schema: raw_schema()
    }
  end

  defp schema_with_id do
    %Avrora.Schema{
      id: 42,
      version: nil,
      schema: erlavro_schema(),
      raw_schema: raw_schema()
    }
  end

  defp erlavro_schema do
    :avro_json_decoder.decode_schema(raw_schema())
  end

  defp raw_schema do
    ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end
end
