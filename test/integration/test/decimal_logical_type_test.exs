defmodule Integration.DecimalLogicalTypeTest do
  use ExUnit.Case

  @tag :integration
  describe "decimal logical type" do
    test "when decimal library is not installed" do
      json = ~s(
        {
          "namespace": "io.confluent",
          "name": "Decimal_Test",
          "type": "record",
          "fields": [
            {
              "name": "decimal",
              "type": {
                "type": "bytes",
                "precision": 3,
                "logicalType": "Decimal",
                "scale": 2
              }
            }
          ]
        }
      )

      {:ok, _} = Avrora.start_link()
      {:ok, schema} = Avrora.Schema.Encoder.from_json(json)

      schema = %{schema | id: nil, version: nil}
      message = <<16, 255, 255, 255, 255, 255, 254, 29, 192>>

      assert {:error, :missing_decimal_module} == Avrora.Codec.Plain.decode(message, schema: schema)
    end
  end
end
