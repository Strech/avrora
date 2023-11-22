defmodule Avrora.Hook.LogicalTypesConversionTest do
  use ExUnit.Case, async: true
  doctest Avrora.Hook.LogicalTypesConversion

  import Mox
  import Support.Config

  alias Avrora.{Codec, Schema}

  setup :verify_on_exit!
  setup :support_config

  describe "process/4" do
    test "when logical types must be kept as is" do
      stub(Avrora.ConfigMock, :convert_logical_types, fn -> false end)

      {:ok, decoded} = Codec.Plain.decode(message(), schema: schema())

      assert decoded == %{"birthday" => 17100}
    end

    test "when logical types must be converted" do
      {:ok, decoded} = Codec.Plain.decode(message(), schema: schema())

      assert decoded == %{"birthday" => ~D[2016-10-26]}
    end
  end

  defp message, do: <<152, 139, 2>>

  defp schema do
    {:ok, schema} = Schema.Encoder.from_json(json_schema())
    %{schema | id: nil, version: nil}
  end

  defp json_schema do
    ~s({"namespace":"io.confluent","name":"Logical_Type","type":"record","fields":[{"name":"birthday","type":{"type": "int","logicalType":"Date"}}]})
  end
end
