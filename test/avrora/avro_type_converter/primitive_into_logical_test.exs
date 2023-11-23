defmodule Avrora.AvroTypeConverter.PrimitiveIntoLogicalTest do
  use ExUnit.Case, async: true
  doctest Avrora.AvroTypeConverter.PrimitiveIntoLogical

  import Mox
  import Support.Config

  alias Avrora.{Codec, Schema}

  setup :verify_on_exit!
  setup :support_config

  describe "convert/2" do
    test "when logical types must be kept as is" do
      stub(Avrora.ConfigMock, :decode_logical_types, fn -> false end)

      {:ok, decoded} = Codec.Plain.decode(message(), schema: schema())

      assert decoded == %{"birthday" => 17100, "number" => 17100}
    end

    test "when logical types must be converted" do
      {:ok, decoded} = Codec.Plain.decode(message(), schema: schema())

      assert decoded == %{"birthday" => ~D[2016-10-26], "number" => 17100}
    end

    test "when logical types must be converted, but it is unknown logical type" do
      result = Codec.Plain.decode(message(), schema: malformed_schema())

      assert result == {:error, %RuntimeError{message: "unknown logical type `Something'"}}
    end
  end

  defp message, do: <<152, 139, 2, 152, 139, 2>>

  defp schema do
    {:ok, schema} = Schema.Encoder.from_json(json_schema())
    %{schema | id: nil, version: nil}
  end

  defp malformed_schema do
    {:ok, schema} = Schema.Encoder.from_json(malformed_json_schema())
    %{schema | id: nil, version: nil}
  end

  defp json_schema do
    ~s({"namespace":"io.confluent","name":"Logical_Type","type":"record","fields":[{"name":"number","type":"int"},{"name":"birthday","type":{"type": "int","logicalType":"Date"}}]})
  end

  defp malformed_json_schema do
    ~s({"namespace":"io.confluent","name":"Logical_Type","type":"record","fields":[{"name":"number","type":"int"},{"name":"birthday","type":{"type": "int","logicalType":"Something"}}]})
  end
end
