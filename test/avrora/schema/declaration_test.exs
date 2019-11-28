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

      assert declaration.referenced == []

      assert sort(declaration.defined) ==
               sort(~w(io.confluent.Account io.confluent.Value io.confluent.Option))
    end

    test "when schema contains arrays" do
      {:ok, declaration} = Declaration.extract(record_with_array())

      assert declaration.referenced == ~w(io.confluent.Payment)
      assert sort(declaration.defined) == sort(~w(io.confluent.Account io.confluent.Tag))
    end
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
          {"name": "id", "type": "int"},
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
