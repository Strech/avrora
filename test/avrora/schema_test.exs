defmodule Avrora.SchemaTest do
  use ExUnit.Case, async: true
  doctest Avrora.Schema

  alias Avrora.Schema

  describe "parse/1" do
    test "when payload is a valid json schema" do
      {:ok, schema} = Schema.parse(payment_json())
      {:ok, {type, _, _, _, _, fields, full_name, _}} = Schema.to_erlavro(schema)

      assert type == :avro_record_type
      assert full_name == "io.confluent.Payment"
      assert length(fields) == 2

      assert schema.full_name == "io.confluent.Payment"
      assert schema.json == payment_json()
    end

    test "when payload is an invalid json shema" do
      assert Schema.parse("a:b") == {:error, "argument error"}
      assert Schema.parse("{}") == {:error, {:not_found, "type"}}
    end
  end

  describe "to_erlavro" do
    test "when payload is a valid json schema" do
      {:ok, schema} = Schema.parse(payment_json())
      {:ok, {type, _, _, _, _, fields, full_name, _}} = Schema.to_erlavro(schema)

      assert type == :avro_record_type
      assert full_name == "io.confluent.Payment"
      assert length(fields) == 2
    end
  end

  defp payment_json do
    ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end
end
