defmodule Avrora.Schema.DeclarationTest do
  use ExUnit.Case, async: true
  doctest Avrora.Schema.Declaration

  alias Avrora.Schema.Declaration

  describe "extract/1" do
    test "when schema contains only primitive types" do
      {:ok, declaration} = Declaration.extract(record_with_primitive())

      assert declaration.referenced == []
      assert sort(declaration.defined) == sort(~w(io.confluent.Payment io.confluent.Transfer))
    end

    test "when schema contains primitive and reference types" do
      {:ok, declaration} = Declaration.extract(record_with_reference())

      assert declaration.referenced == ~w(io.confluent.PaymentHistory)
      assert declaration.defined == ~w(io.confluent.Account)
    end

    test "when schema contains maps" do
      {:ok, declaration} = Declaration.extract(record_with_map())

      assert declaration.referenced == ~w(io.confluent.Payment)

      assert sort(declaration.defined) ==
               sort(~w(io.confluent.Account io.confluent.Value io.confluent.Option))
    end

    test "when schema contains arrays" do
      {:ok, declaration} = Declaration.extract(record_with_array())

      assert declaration.referenced == ~w(io.confluent.Payment)
      assert sort(declaration.defined) == sort(~w(io.confluent.Account io.confluent.Tag))
    end

    test "when schema contains enums" do
      {:ok, declaration} = Declaration.extract(record_with_enum())

      assert declaration.referenced == []
      assert declaration.defined == ~w(io.confluent.Image)
    end

    test "when schema contains unions" do
      {:ok, declaration} = Declaration.extract(record_with_union())

      assert declaration.referenced == ~w(io.confluent.Image)
      assert sort(declaration.defined) == sort(~w(io.confluent.Message io.confluent.Contact))
    end

    test "when schema contains fixed" do
      {:ok, declaration} = Declaration.extract(record_with_fixed())

      assert declaration.referenced == ~w()
      assert declaration.defined == ~w(io.confluent.Image)
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

  defp record_with_reference do
    ~s(
      {
        "type": "record",
        "name": "Account",
        "namespace": "io.confluent",
        "fields": [
          {"name": "id", "type": "int"},
          {"name": "payment_history", "type": "io.confluent.PaymentHistory"}
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

  defp sort(value), do: Enum.sort(value)
  defp decode_schema(json), do: :avro_json_decoder.decode_schema(json, allow_bad_references: true)
end
