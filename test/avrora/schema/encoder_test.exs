defmodule Avrora.Schema.EncoderTest do
  use ExUnit.Case, async: true
  doctest Avrora.Schema.Encoder

  import Support.Config
  alias Avrora.Schema

  setup :support_config

  describe "from_json/2" do
    test "when schema is primitive type" do
      {:ok, schema} = Schema.Encoder.from_json(string_json(), name: "io.acme.String")
      {:ok, {type, type_name, _}} = Schema.Encoder.to_erlavro(schema)

      assert type == :avro_primitive_type
      assert type_name == "string"
    end

    test "when schema is Array type" do
      {:ok, schema} = Schema.Encoder.from_json(array_json(), name: "io.acme.Array")
      {:ok, {type, {item_type, item_type_name, _}, _}} = Schema.Encoder.to_erlavro(schema)

      assert type == :avro_array_type
      assert item_type == :avro_primitive_type
      assert item_type_name == "string"
    end

    test "when schema is Union type with primitives" do
      {:ok, schema} = Schema.Encoder.from_json(union_json(), name: "io.acme.Union")
      {:ok, {type, {2, fields}, _}} = Schema.Encoder.to_erlavro(schema)
      {1, field1, {0, field2, _, _}, _} = fields

      assert type == :avro_union_type

      {type, type_name, _} = field1
      assert type == :avro_primitive_type
      assert type_name == "int"

      {type, type_name, _} = field2
      assert type == :avro_primitive_type
      assert type_name == "string"
    end

    test "when schema is Union type with nested type ref" do
      {:ok, schema} =
        Schema.Encoder.from_json(union_with_reference_json(),
          name: "io.acme.Union",
          reference_lookup_fun: fn name ->
            case name do
              "io.acme.Message" -> {:ok, message_with_reference_json()}
              "io.acme.Signature" -> {:ok, signature_json()}
              "io.acme.Attachment" -> {:ok, attachment_json()}
              _ -> raise "unknown reference name!"
            end
          end
        )

      {:ok, {type, {2, fields}, _}} = Schema.Encoder.to_erlavro(schema)
      {1, field1, {0, field2, _, _}, _} = fields

      assert type == :avro_union_type

      {type, _, _, _, _, fields, full_name, _} = field1
      assert type == :avro_record_type
      assert full_name == "io.acme.Message"
      assert length(fields) == 2

      {type, type_name, _} = field2
      assert type == :avro_primitive_type
      assert type_name == "string"
    end

    test "when schema is Enum type" do
      {:ok, schema} = Schema.Encoder.from_json(card_type_json())
      {:ok, {type, _, _, _, _, fields, full_name, _}} = Schema.Encoder.to_erlavro(schema)

      assert type == :avro_enum_type
      assert full_name == "io.acme.CardType"
      assert length(fields) == 3

      assert schema.full_name == "io.acme.CardType"
      assert schema.json == card_type_json()
    end

    test "when payload is Fixed type" do
      {:ok, schema} = Schema.Encoder.from_json(crc32_json())
      {:ok, {type, _, _, _, value, full_name, _}} = Schema.Encoder.to_erlavro(schema)

      assert type == :avro_fixed_type
      assert full_name == "io.acme.CRC32"
      assert value == 8

      assert schema.full_name == "io.acme.CRC32"
      assert schema.json == crc32_json()
    end

    test "when schema is Record type with primitive fields types" do
      {:ok, schema} = Schema.Encoder.from_json(payment_json())
      {:ok, {type, _, _, _, _, fields, full_name, _}} = Schema.Encoder.to_erlavro(schema)

      assert type == :avro_record_type
      assert full_name == "io.acme.Payment"
      assert length(fields) == 2

      assert schema.full_name == "io.acme.Payment"
      assert schema.json == payment_json()
    end

    test "when schema is Record type with nested type ref" do
      {:ok, schema} =
        Schema.Encoder.from_json(message_with_reference_json(),
          reference_lookup_fun: fn name ->
            case name do
              "io.acme.Signature" -> {:ok, signature_json()}
              "io.acme.Attachment" -> {:ok, attachment_json()}
              _ -> raise "unknown reference name!"
            end
          end
        )

      {:ok, {type, _, _, _, _, fields, full_name, _}} = Schema.Encoder.to_erlavro(schema)

      assert type == :avro_record_type
      assert full_name == "io.acme.Message"
      assert length(fields) == 2

      assert schema.full_name == "io.acme.Message"
      assert schema.json == message_json()

      {:avro_record_field, _, _, body_type, _, _, _} = List.first(fields)
      assert body_type == {:avro_primitive_type, "string", []}

      {:avro_record_field, _, _, attachments_type, _, _, _} = List.last(fields)
      {:avro_array_type, {type, _, _, _, _, fields, full_name, _}, []} = attachments_type

      assert type == :avro_record_type
      assert full_name == "io.acme.Attachment"
      assert length(fields) == 2

      {:avro_record_field, _, _, signature_type, _, _, _} = List.last(fields)
      {type, _, _, _, _, fields, full_name, _} = signature_type

      assert type == :avro_record_type
      assert full_name == "io.acme.Signature"
      assert length(fields) == 1
    end

    test "when schema is Record type with type ref of invalid schema" do
      result =
        Schema.Encoder.from_json(message_with_reference_json(),
          reference_lookup_fun: fn name ->
            assert name == "io.acme.Attachment"
            {:ok, "{}"}
          end
        )

      assert {:error, {:not_found, "type"}} == result
    end

    test "when schema is Record type with type ref and resolution failed" do
      result =
        Schema.Encoder.from_json(message_with_reference_json(),
          reference_lookup_fun: fn name ->
            assert name == "io.acme.Attachment"
            {:error, :bad_thing_happen}
          end
        )

      assert {:error, :bad_thing_happen} == result
    end

    test "when schema is primitive type without name" do
      {:error, {:unnamed_type, _}} = Schema.Encoder.from_json(string_json())
    end

    test "when schema is Record type with type ref and lookup function given" do
      assert {:error, :undefined_reference_lookup_function} ==
               Schema.Encoder.from_json(message_with_reference_json())
    end

    test "when schema is an invalid" do
      assert Schema.Encoder.from_json("a:b") == {:error, "argument error"}
      assert Schema.Encoder.from_json("{}") == {:error, {:not_found, "type"}}
      assert Schema.Encoder.from_json("[null]") == {:error, :invalid_schema}
    end
  end

  describe "to_erlavro/1" do
    test "when payload is a valid json schema" do
      {:ok, schema} = Schema.Encoder.from_json(payment_json())
      {:ok, {type, _, _, _, _, fields, full_name, _}} = Schema.Encoder.to_erlavro(schema)

      assert type == :avro_record_type
      assert full_name == "io.acme.Payment"
      assert length(fields) == 2
    end
  end

  describe "from_erlavro/2" do
    test "when payload is valid and no attributes are given" do
      {:ok, schema} = Schema.Encoder.from_erlavro(payment_erlavro())

      assert is_nil(schema.id)
      assert is_nil(schema.version)

      assert schema.full_name == "io.acme.Payment"
      assert schema.json == payment_json()
    end

    test "when payload is valid and JSON attribute is given" do
      {:ok, schema} = Schema.Encoder.from_erlavro(payment_erlavro(), json: "{}")

      assert is_nil(schema.id)
      assert is_nil(schema.version)

      assert schema.full_name == "io.acme.Payment"
      assert schema.json == "{}"
    end

    test "when payload is not a named type schema" do
      assert Schema.Encoder.from_erlavro(unnamed_erlavro()) == {:error, :unnamed_type}
    end
  end

  defp payment_erlavro do
    {:avro_record_type, "Payment", "io.acme", "", [],
     [
       {:avro_record_field, "id", "", {:avro_primitive_type, "string", []}, :undefined, :ascending, []},
       {:avro_record_field, "amount", "", {:avro_primitive_type, "double", []}, :undefined, :ascending, []}
     ], "io.acme.Payment", []}
  end

  defp unnamed_erlavro, do: {:avro_array_type, {:avro_primitive_type, "string", []}, []}
  defp union_json, do: ~s(["string", "int"])
  defp union_with_reference_json, do: ~s(["string", "io.acme.Message"])
  defp string_json, do: ~s({"type": "string"})
  defp array_json, do: ~s({"type":"array","items":"string","default":[]})
  defp crc32_json, do: ~s({"namespace":"io.acme","name":"CRC32","type":"fixed","size":8})

  defp signature_json do
    ~s({"namespace":"io.acme","name":"Signature","type":"record","fields":[{"name":"checksum","type":{"name":"SignatureChecksum","type":"fixed","size":1048576}}]})
  end

  defp attachment_json do
    ~s({"namespace":"io.acme","name":"Attachment","type":"record","fields":[{"name":"name","type":"string"},{"name":"signature","type":"io.acme.Signature"}]})
  end

  defp payment_json do
    ~s({"namespace":"io.acme","name":"Payment","type":"record","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end

  defp card_type_json do
    ~s({"namespace":"io.acme","name":"CardType","type":"enum","symbols":["MASTERCARD","VISA","AMERICANEXPRESS"]})
  end

  defp message_with_reference_json do
    ~s({"namespace":"io.acme","name":"Message","type":"record","fields":[{"name":"body","type":"string"},{"name":"attachments","type":{"type":"array","items":"io.acme.Attachment"}}]})
  end

  defp message_json do
    ~s({"namespace":"io.acme","name":"Message","type":"record","fields":[{"name":"body","type":"string"},{"name":"attachments","type":{"type":"array","items":{"name":"Attachment","type":"record","fields":[{"name":"name","type":"string"},{"name":"signature","type":{"name":"Signature","type":"record","fields":[{"name":"checksum","type":{"name":"SignatureChecksum","type":"fixed","size":1048576}}]}}]}}}]})
  end
end
