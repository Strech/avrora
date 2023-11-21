defmodule Avrora.Hook.NullValueConversionTest do
  use ExUnit.Case, async: true
  doctest Avrora.Hook.NullValueConversion

  import Mox
  import Support.Config

  alias Avrora.{Codec, Schema}

  setup :verify_on_exit!
  setup :support_config

  describe "process/4" do
    test "when null values must be kept as is" do
      stub(Avrora.ConfigMock, :convert_null_values, fn -> false end)

      {:ok, decoded} = Codec.Plain.decode(message(), schema: schema())

      assert decoded == %{"key" => "user-1", "value" => :null}
    end

    test "when null values must be converted" do
      {:ok, decoded} = Codec.Plain.decode(message(), schema: schema())

      assert decoded == %{"key" => "user-1", "value" => nil}
    end
  end

  defp message, do: <<12, 117, 115, 101, 114, 45, 49, 0>>

  defp schema do
    {:ok, schema} = Schema.Encoder.from_json(json_schema())
    %{schema | id: nil, version: nil}
  end

  defp json_schema do
    ~s({"namespace":"io.confluent","name":"Null_Value","type":"record","fields":[{"name":"key","type":"string"},{"name":"value","type":["null","int"]}]})
  end
end
