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

    test "when payload is a valid json schema with external reference and callback is given" do
      {:ok, schema} =
        Schema.parse(message_with_reference_json(),
          callback: fn name ->
            assert name == "io.confluent.Attachment"

            attachment_erlavro()
          end
        )

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
      assert length(fields) == 2
    end

    test "when payload is a valid json schema with external reference and no callback is given" do
      assert {:error, :bad_reference} == Schema.parse(message_with_reference_json())
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

  defp attachment_erlavro do
    {:avro_record_type, "Attachment", "io.confluent", "", [],
     [
       {:avro_record_field, "name", "", {:avro_primitive_type, "string", []}, :undefined,
        :ascending, []},
       {:avro_record_field, "extension", "", {:avro_primitive_type, "string", []}, :undefined,
        :ascending, []}
     ], "io.confluent.Attachment", []}
  end

  defp payment_json do
    ~s({"namespace":"io.confluent","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end

  defp message_with_reference_json do
    ~s({"namespace":"io.confluent","name":"Message","type":"record","fields":[{"name":"body","type":"string"},{"name":"attachments","type":{"type":"array","items":"io.confluent.Attachment"}}]})
  end

  defp message_json do
    ~s({"namespace":"io.confluent","name":"Message","type":"record","fields":[{"name":"body","type":"string"},{"name":"attachments","type":{"type":"array","items":{"name":"Attachment","type":"record","fields":[{"name":"name","type":"string"},{"name":"extension","type":"string"}]}}}]})
  end
end
