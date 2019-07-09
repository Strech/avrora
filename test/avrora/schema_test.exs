defmodule Avrora.SchemaTest do
  use ExUnit.Case, async: true
  doctest Avrora.Schema

  alias Avrora.Schema

  describe "parse/1" do
    test "when payload is a valid avro json string" do
      {:ok, avro} = Schema.parse(payment_schema())

      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert length(avro.ex_schema.schema.fields) == 2
      assert avro.raw_schema == parsed_payment_schema()
    end

    test "when payload is a valid avro mapped to elixir map" do
      {:ok, avro} = Schema.parse(parsed_payment_schema())

      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert length(avro.ex_schema.schema.fields) == 2
      assert avro.raw_schema == parsed_payment_schema()
    end

    test "when payload is invalid json string" do
      {:error, reason} = Schema.parse("hello:world")

      assert %Jason.DecodeError{} = reason
    end

    test "when payload is invalid elixir map" do
      {:error, reason} = Schema.parse(%{"type" => "record"})

      assert reason == %{name: ["can't be blank"]}
    end
  end

  describe "parse_subject/1" do
    test "when only name part is present" do
      assert Schema.parse_subject("hello") == "hello"
      assert Schema.parse_subject("io.hello.world") == "io.hello.world"
    end

    test "when name and version parts are present" do
      assert Schema.parse_subject("hello:6") == "hello"
      assert Schema.parse_subject("io.hello.world:42") == "io.hello.world"
    end
  end

  describe "parse_version/1" do
    test "when only name part is present" do
      assert is_nil(Schema.parse_version("hello"))
      assert is_nil(Schema.parse_version("io.hello.world"))
    end

    test "when name and version parts are present" do
      assert Schema.parse_version("hello:6") == 6
      assert Schema.parse_version("io.hello.world:42") == 42
    end
  end

  defp parsed_payment_schema do
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

  defp payment_schema do
    ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end
end
