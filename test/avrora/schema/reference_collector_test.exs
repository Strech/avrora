defmodule Avrora.Schema.ReferenceCollectorTest do
  use ExUnit.Case, async: true
  doctest Avrora.Schema.ReferenceCollector

  alias Avrora.Schema.ReferenceCollector

  describe "collect/1" do
    test "when schema contains only primitive types" do
      {:ok, references} = ReferenceCollector.collect(record_with_primitive())

      assert references == []
    end

    test "when schema contains primitive and reference types" do
      {:ok, references} = ReferenceCollector.collect(record_with_reference())

      assert Enum.sort(references) ==
               Enum.sort(~w(io.confluent.PaymentHistory io.confluent.Message))
    end

    test "when schema contains primitive, sub-type and alias reference" do
      {:ok, references} = ReferenceCollector.collect(record_with_alias_reference())

      assert references == Enum.sort(~w(io.confluent.PaymentHistory))
    end

    test "when schema contains maps" do
      {:ok, references} = ReferenceCollector.collect(record_with_map())

      assert references == ~w(io.confluent.Payment)
    end

    test "when schema contains arrays" do
      {:ok, references} = ReferenceCollector.collect(record_with_array())

      assert references == ~w(io.confluent.Payment)
    end

    test "when schema contains enums" do
      {:ok, references} = ReferenceCollector.collect(record_with_enum())

      assert references == []
    end

    test "when schema contains unions" do
      {:ok, references} = ReferenceCollector.collect(record_with_union())

      assert references == ~w(io.confluent.Image)
    end

    test "when schema contains fixed" do
      {:ok, references} = ReferenceCollector.collect(record_with_fixed())

      assert references == []
    end

    test "when schema contains many fields" do
      {:ok, references} = ReferenceCollector.collect(record_with_many_fields())

      assert references == []
    end
  end

  defp record_with_fixed do
    ~s(
      {
        "type": "record",
        "name": "Image",
        "namespace": "io.confluent",
        "fields": [
          {
            "name": "blob",
            "type": {
              "type": "fixed",
              "name": "ImageSize",
              "size": 1048576
            }
          }
        ]
      }
    ) |> decode_schema()
  end

  defp record_with_union do
    ~s(
      {
        "type": "record",
        "name": "Message",
        "namespace": "io.confluent",
        "fields": [
          {
            "name": "attachment",
            "type": [
              "string",
              "io.confluent.Image",
              {
                "type": "record",
                "name": "Contact",
                "fields": [{"name": "email", "type": "string"}]
              }
            ]
          }
        ]
      }
    ) |> decode_schema()
  end

  defp record_with_enum do
    ~s(
      {
        "type": "record",
        "name": "Image",
        "namespace": "io.confluent",
        "fields": [
          {
            "name": "orientation",
            "type": {
              "type": "enum",
              "name": "OrientationVariants",
              "symbols": ["landscape", "portrait"]
            }
          }
        ]
      }
    ) |> decode_schema()
  end

  defp record_with_array do
    ~s(
      {
        "type": "record",
        "name": "Account",
        "namespace": "io.confluent",
        "fields": [
          {
            "name": "payment_history",
            "type": {"type": "array", "items": "io.confluent.Payment"}
          },
          {
            "name": "colors",
            "type": {"type": "array", "items": "string"}
          },
          {
            "name": "tags",
            "type": {
              "type": "array",
              "items": {
                "type": "record",
                "name": "Tag",
                "fields": [{"name": "value", "type": "string"}]
              }
            }
          }
        ]
      }
    ) |> decode_schema()
  end

  defp record_with_map do
    ~s(
      {
        "type": "record",
        "name": "Account",
        "namespace": "io.confluent",
        "fields": [
          {
            "name": "tags",
            "type": {
              "type": "map",
              "values": "string"
            }
          },
          {
            "name": "payment_history",
            "type": {
              "type": "map",
              "values": "io.confluent.Payment"
            }
          },
          {
            "name": "settings",
            "type": {
              "type": "map",
              "values": {
                "type": "record",
                "name": "Value",
                "aliases": ["Option"],
                "fields": [{"name": "value", "type": "string"}]
              }
            }
          }
        ]
      }
    ) |> decode_schema()
  end

  defp record_with_alias_reference do
    ~s(
      {
        "type": "record",
        "name": "Account",
        "namespace": "io.confluent",
        "fields": [
          {"name": "id", "type": "int"},
          {"name": "payment_history", "type": "io.confluent.PaymentHistory"},
          {"name": "letters", "type": {"type": "array", "items": "io.confluent.Letter"}},
          {
            "name": "messages",
            "type": {
              "type": "array",
              "items": {
                "name": "Message",
                "type": "record",
                "aliases": ["Letter"],
                "fields": [{"name": "body", "type": "string"}]
              }
            }
          }
        ]
      }
    ) |> decode_schema()
  end

  defp record_with_reference do
    ~s(
      {
        "type": "record",
        "name": "Account",
        "namespace": "io.confluent",
        "fields": [
          {"name": "id", "type": "int"},
          {"name": "payment_history", "type": "io.confluent.PaymentHistory"},
          {"name": "messages", "type": {"type": "array", "items": "io.confluent.Message"}}
        ]
      }
    ) |> decode_schema()
  end

  defp record_with_primitive do
    ~s(
      {
        "type": "record",
        "name": "Payment",
        "namespace": "io.confluent",
        "aliases": ["Transfer"],
        "fields": [
          {"name": "id", "type": "string"},
          {"name": "amount", "type": "double"}
        ]
      }
    ) |> decode_schema()
  end

  defp record_with_many_fields do
    File.read!(
      Path.join(__DIR__, "../../../test/fixtures/schemas/io/confluent/MailgunEvent.avsc")
    )
    |> decode_schema()
  end

  defp decode_schema(json), do: :avro_json_decoder.decode_schema(json, allow_bad_references: true)
end
