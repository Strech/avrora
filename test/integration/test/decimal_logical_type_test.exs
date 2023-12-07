defmodule Integration.DecimalLogicalTypeTest do
  use ExUnit.Case

  alias Avrora.{Codec, Schema}

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
                "logicalType": "decimal",
                "scale": 2
              }
            }
          ]
        }
      )

      {:ok, _} = Avrora.start_link()
      {:ok, schema} = Schema.Encoder.from_json(json)

      schema = %{schema | id: nil, version: nil}
      message = <<16, 255, 255, 255, 255, 255, 254, 29, 192>>

      {:error, error} = Codec.Plain.decode(message, schema: schema)

      assert error.code == :missing_decimal_lib
      assert Exception.message(error) =~ "missing `Decimal' library"
    end
  end
end
