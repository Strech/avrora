defmodule Avrora.EncoderTest do
  use ExUnit.Case, async: true
  doctest Avrora.Encoder

  import Mox
  import ExUnit.CaptureLog
  alias Avrora.Encoder

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

  defp magic_message do
    <<0, 0, 0, 0, 42, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48,
      45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71,
      225, 250, 47, 64>>
  end

  defp not_magic_message do
    <<72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48,
      48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64>>
  end

  defp schema do
    %Avrora.Schema{
      id: nil,
      version: nil,
      ex_schema: ex_schema(),
      raw_schema: raw_schema()
    }
  end

  defp schema_with_version do
    %Avrora.Schema{
      id: nil,
      version: 42,
      ex_schema: ex_schema(),
      raw_schema: raw_schema()
    }
  end

  defp ex_schema do
    AvroEx.Schema.parse!(Jason.encode!(raw_schema()))
  end

  defp raw_schema do
    %{
      "namespace" => "io.confluent",
      "type" => "record",
      "name" => "Payment",
      "fields" => [
        %{"name" => "id", "type" => "string"},
        %{"name" => "amount", "type" => "double"}
      ]
    }
  end
end
