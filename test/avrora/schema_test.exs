defmodule Avrora.SchemaTest do
  use ExUnit.Case, async: true
  doctest Avrora.Schema

  alias Avrora.Schema

  describe "parse/2" do
    test "when payload is a valid json schema" do
      {:ok, schema} = Schema.parse(payment_json())
      {:ok, {type, _, _, _, _, fields, full_name, _}} = Schema.to_erlavro(schema)

      assert type == :avro_record_type
      assert full_name == "io.confluent.Payment"
      assert length(fields) == 2

      assert schema.full_name == "io.confluent.Payment"
      assert schema.json == payment_json()
    end

    test "when payload is a valid json schema with external reference and callback returns valid schema" do
      {:ok, schema} =
        Schema.parse(message_with_reference_json(), fn name ->
          assert name == "io.confluent.Attachment"
          {:ok, attachment_json()}
        end)

      {:ok, {type, _, _, _, _, fields, full_name, _}} = Schema.to_erlavro(schema)

      assert type == :avro_record_type
      assert full_name == "io.confluent.Message"
      assert length(fields) == 2

      assert schema.full_name == "io.confluent.Message"
      assert schema.json == message_json()

      {:avro_record_field, _, _, body_type, _, _, _} = List.first(fields)
      assert body_type == {:avro_primitive_type, "string", []}

      {:avro_record_field, _, _, attachments_type, _, _, _} = List.last(fields)
      {:avro_array_type, {type, _, _, _, _, fields, full_name, _}, []} = attachments_type

      assert type == :avro_record_type
      assert full_name == "io.confluent.Attachment"
      assert length(fields) == 1
    end

    test "when payload is a valid json schema with external reference and callback returns invalid schema" do
      result =
        Schema.parse(message_with_reference_json(), fn name ->
          assert name == "io.confluent.Attachment"
          {:ok, ~s({})}
        end)

      {:error, {:not_found, "type"}} = result
    end

    test "when payload is a valid json schema with external reference and callback returns error" do
      result =
        Schema.parse(message_with_reference_json(), fn name ->
          assert name == "io.confluent.Attachment"
          {:error, :bad_thing_happen}
        end)

      assert {:error, :bad_thing_happen} == result
    end

    test "when payload is a valid json schema with external reference and no callback is given" do
      assert {:error, {:not_found, "type"}} == Schema.parse(message_with_reference_json())
    end

    test "when payload is an invalid json schema" do
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

  defp attachment_json do
    ~s({"namespace":"io.confluent","name":"Attachment","type":"record","fields":[{"name":"name","type":"string"}]})
  end

  defp payment_json do
    ~s({"namespace":"io.confluent","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end

  defp message_with_reference_json do
    ~s({"namespace":"io.confluent","name":"Message","type":"record","fields":[{"name":"body","type":"string"},{"name":"attachments","type":{"type":"array","items":"io.confluent.Attachment"}}]})
  end

  defp message_json do
    ~s({"namespace":"io.confluent","name":"Message","type":"record","fields":[{"name":"body","type":"string"},{"name":"attachments","type":{"type":"array","items":{"name":"Attachment","type":"record","fields":[{"name":"name","type":"string"}]}}}]})
  end
end
