defmodule Mix.Tasks.Avrora.Reg.SchemaTest do
  use ExUnit.Case
  doctest Mix.Tasks.Avrora.Reg.Schema

  import Mox
  import Support.Config

  alias Avrora.Schema
  alias Mix.Tasks.Avrora.Reg.Schema, as: Task

  setup :verify_on_exit!
  setup :support_config

  describe "run/1" do
    test "when no arguments were given" do
      assert {:shutdown, 1} == catch_exit(Task.run([]))

      assert_received {:mix_shell, :error, [output]}
      assert output =~ "don't know how to handle"
    end

    test "when --name NAME argument was given" do
      stub(Avrora.ConfigMock, :schemas_path, fn -> Path.expand("./test/fixtures/mix/schemas") end)

      payment_schema_with_id = payment_schema_with_id()

      Avrora.Storage.MemoryMock
      |> expect(:put, fn key, value ->
        assert key == 1
        assert value == payment_schema_with_id

        {:ok, value}
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

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema_without_id_and_version()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_json_schema()

        {:ok, payment_schema_with_id}
      end)

      Task.run(["--name", "io.confluent.Payment"])

      assert_received {:mix_shell, :info, [output]}
      assert output =~ "schema `io.confluent.Payment' will be registered"
    end

    test "when --name NAME argument was given together with --as NEW_NAME" do
      stub(Avrora.ConfigMock, :schemas_path, fn -> Path.expand("./test/fixtures/mix/schemas") end)

      payment_schema_with_id = payment_schema_with_id()

      Avrora.Storage.MemoryMock
      |> expect(:put, fn key, value ->
        assert key == 1
        assert value == payment_schema_with_id

        {:ok, value}
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

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema_without_id_and_version()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "MyCustomName"
        assert value == payment_json_schema()

        {:ok, payment_schema_with_id}
      end)

      Task.run(["--name", "io.confluent.Payment", "--as", "MyCustomName"])

      assert_received {:mix_shell, :info, [output]}
      assert output =~ "schema `io.confluent.Payment' will be registered as `MyCustomName'"
    end

    test "when --name NAME argument was given with extra spacing" do
      stub(Avrora.ConfigMock, :schemas_path, fn -> Path.expand("./test/fixtures/mix/schemas") end)

      payment_schema_with_id = payment_schema_with_id()

      Avrora.Storage.MemoryMock
      |> expect(:put, fn key, value ->
        assert key == 1
        assert value == payment_schema_with_id

        {:ok, value}
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

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema_without_id_and_version()}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_json_schema()

        {:ok, payment_schema_with_id}
      end)

      Task.run(["--name", "  io.confluent.Payment  "])

      assert_received {:mix_shell, :info, [output]}
      assert output =~ "schema `io.confluent.Payment' will be registered"
    end

    test "when --name NAME argument was given, but schema was not found" do
      stub(Avrora.ConfigMock, :schemas_path, fn -> Path.expand("./test/fixtures/mix/schemas") end)

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "io.unknown.Schema"

        {:error, :enoent}
      end)

      Task.run(["--name", "io.unknown.Schema"])

      assert_received {:mix_shell, :error, [output]}
      assert output =~ "schema `io.unknown.Schema' will be skipped"
    end

    test "when --all argument was given" do
      stub(Avrora.ConfigMock, :schemas_path, fn -> Path.expand("./test/fixtures/mix/schemas") end)

      payment_schema_with_id = payment_schema_with_id()
      event_schema_with_id = event_schema_with_id()

      Avrora.Storage.MemoryMock
      |> expect(:put, fn key, value ->
        assert key == 2
        assert value == event_schema_with_id

        {:ok, value}
      end)
      |> expect(:put, fn key, value ->
        assert key == "com.mailgun.Event"
        assert value == event_schema_with_id

        {:ok, value}
      end)
      |> expect(:expire, fn key, ttl ->
        assert key == "com.mailgun.Event"
        assert ttl == :infinity

        {:ok, :infinity}
      end)
      |> expect(:put, fn key, value ->
        assert key == 1
        assert value == payment_schema_with_id

        {:ok, value}
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

      Avrora.Storage.FileMock
      |> expect(:get, fn key ->
        assert key == "com.mailgun.Event"

        {:ok, event_schema_without_id_and_version()}
      end)
      |> expect(:get, fn key ->
        assert key == "io.confluent.Payment"

        {:ok, payment_schema_without_id_and_version()}
      end)
      |> expect(:get, fn key ->
        assert key == "io.confluent.Wrong"

        {:error, "this schema is wrong"}
      end)

      Avrora.Storage.RegistryMock
      |> expect(:put, fn key, value ->
        assert key == "com.mailgun.Event"
        assert value == event_json_schema()

        {:ok, event_schema_with_id}
      end)
      |> expect(:put, fn key, value ->
        assert key == "io.confluent.Payment"
        assert value == payment_json_schema()

        {:ok, payment_schema_with_id}
      end)

      Task.run(["--all"])

      assert_received {:mix_shell, :info, [output]}
      assert output =~ "schema `com.mailgun.Event' will be registered"

      assert_received {:mix_shell, :info, [output]}
      assert output =~ "schema `io.confluent.Payment' will be registered"

      assert_received {:mix_shell, :error, [output]}
      assert output =~ "schema `io.confluent.Wrong' will be skipped"
    end
  end

  defp payment_schema_with_id do
    {:ok, schema} = Schema.parse(payment_json_schema())
    %{schema | id: 1, version: nil}
  end

  defp payment_schema_without_id_and_version do
    {:ok, schema} = Schema.parse(payment_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp payment_json_schema do
    ~s({"namespace":"io.confluent","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end

  defp event_schema_with_id do
    {:ok, schema} = Schema.parse(event_json_schema())
    %{schema | id: 2, version: nil}
  end

  defp event_schema_without_id_and_version do
    {:ok, schema} = Schema.parse(event_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp event_json_schema do
    ~s({"namespace":"com.mailgun","name":"Event","type":"record","fields":[{"name":"id","type":"string"}]})
  end
end
