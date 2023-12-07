defmodule Avrora.AvroTypeConverter.PrimitiveIntoLogicalTest do
  use ExUnit.Case, async: true
  doctest Avrora.AvroTypeConverter.PrimitiveIntoLogical

  import Mox
  import Support.Config
  import ExUnit.CaptureLog

  alias Avrora.{Codec, Schema}

  setup :verify_on_exit!
  setup :support_config

  describe "convert/2" do
    test "when logical types must be kept as is" do
      stub(Avrora.ConfigMock, :decode_logical_types, fn -> false end)

      {:ok, decoded} = Codec.Plain.decode(date_message(), schema: schema(date_json()))

      assert decoded == %{"birthday" => 17100, "number" => 17100}
    end

    test "when logical types must be converted" do
      {:ok, decoded} = Codec.Plain.decode(date_message(), schema: schema(date_json()))

      assert decoded == %{"birthday" => ~D[2016-10-26], "number" => 17100}
    end

    test "when logical types must be converted, but it is unknown logical type" do
      output =
        capture_log(fn ->
          decoded = %{"birthday" => 17100, "number" => 17100}
          assert {:ok, decoded} == Codec.Plain.decode(date_message(), schema: schema(unknown_json()))
        end)

      assert output =~ "unsupported logical type `unknown' was not converted"
    end

    test "when logical type is uuid" do
      {:ok, decoded} = Codec.Plain.decode(uuid_message(), schema: schema(uuid_json()))

      assert decoded == %{"uuid" => "016c25fd-70e0-56fe-9d1a-56e80fa20b82"}
    end

    test "when logical type is decimal without scale" do
      {:ok, decoded} = Codec.Plain.decode(decimal_fixed_message(), schema: schema(decimal_fixed_json()))

      assert decoded == %{"decimal" => Decimal.new("123456")}
    end

    test "when logical type is decimal with scale" do
      {:ok, decoded} = Codec.Plain.decode(decimal_bytes_message(), schema: schema(decimal_bytes_json()))

      assert decoded == %{"decimal" => Decimal.new("-1234.56")}
    end

    test "when logical type is time with millisecond precision" do
      {:ok, decoded} = Codec.Plain.decode(time_millis_message(), schema: schema(time_millis_json()))

      assert decoded == %{"time" => ~T[04:28:07.123]}
    end

    test "when logical type is time with microsecond precision" do
      {:ok, decoded} = Codec.Plain.decode(time_micros_message(), schema: schema(time_micros_json()))

      assert decoded == %{"time" => ~T[04:28:07.000000]}
    end

    test "when logical type is timestamp with millisecond precision" do
      {:ok, decoded} = Codec.Plain.decode(timestamp_millis_message(), schema: schema(timestamp_millis_json()))

      assert decoded == %{"timestamp" => ~U[2016-10-26 04:28:07.123Z]}
    end

    test "when logical type is timestamp with microsecond precision" do
      {:ok, decoded} = Codec.Plain.decode(timestamp_micros_message(), schema: schema(timestamp_micros_json()))

      assert decoded == %{"timestamp" => ~U[2016-10-26 04:28:07.000000Z]}
    end

    test "when logical type is timestamp and its value is incorrect" do
      {:error, error} = Codec.Plain.decode(timestamp_invalid_message(), schema: schema(timestamp_millis_json()))

      assert error.code == :invalid_unix_time
      assert Exception.message(error) =~ "invalid UNIX time"
    end

    test "when logical type is local timestamp with millisecond precision" do
      {:ok, decoded} = Codec.Plain.decode(timestamp_millis_message(), schema: schema(local_timestamp_millis_json()))

      assert DateTime.to_string(decoded["timestamp"]) == "2016-10-26 13:28:07.123+09:00 JST Japan"
    end

    test "when logical type is local timestamp with microsecond precision" do
      {:ok, decoded} = Codec.Plain.decode(timestamp_micros_message(), schema: schema(local_timestamp_micros_json()))

      assert DateTime.to_string(decoded["timestamp"]) == "2016-10-26 13:28:07.000000+09:00 JST Japan"
    end

    test "when logical type is local timestamp and its value is incorrect" do
      {:error, error} = Codec.Plain.decode(timestamp_invalid_message(), schema: schema(local_timestamp_millis_json()))

      assert error.code == :invalid_unix_time
      assert Exception.message(error) =~ "invalid UNIX time"
    end
  end

  defp date_message, do: <<152, 139, 2, 152, 139, 2>>
  defp uuid_message, do: "H016c25fd-70e0-56fe-9d1a-56e80fa20b82"
  defp decimal_fixed_message, do: <<0, 0, 0, 0, 0, 1, 226, 64>>
  defp decimal_bytes_message, do: <<16, 255, 255, 255, 255, 255, 254, 29, 192>>
  defp time_millis_message, do: <<166, 225, 171, 15>>
  defp time_micros_message, do: <<128, 143, 225, 237, 119>>
  defp timestamp_millis_message, do: <<166, 161, 246, 243, 255, 85>>
  defp timestamp_micros_message, do: <<128, 143, 229, 211, 161, 239, 159, 5>>
  defp timestamp_invalid_message, do: <<128, 128, 155, 199, 153, 131, 162, 132, 7>>

  defp schema(json) do
    {:ok, schema} = Schema.Encoder.from_json(json)
    %{schema | id: nil, version: nil}
  end

  defp date_json do
    ~s({"namespace":"io.confluent","name":"Date","type":"record","fields":[{"name":"number","type":"int"},{"name":"birthday","type":{"type": "int","logicalType":"date"}}]})
  end

  defp unknown_json do
    ~s({"namespace":"io.confluent","name":"Unknown","type":"record","fields":[{"name":"number","type":"int"},{"name":"birthday","type":{"type":"int","logicalType":"unknown"}}]})
  end

  defp uuid_json do
    ~s({"namespace":"io.confluent","name":"Uuid","type":"record","fields":[{"name":"uuid","type":{"type":"string","logicalType":"uuid"}}]})
  end

  defp decimal_fixed_json do
    ~s({"namespace":"io.confluent","name":"Decimal_Without_Scale","type":"record","fields":[{"name":"decimal","type":{"type":"fixed","size":8,"precision":3,"name":"money","logicalType":"decimal"}}]})
  end

  defp decimal_bytes_json do
    ~s({"namespace":"io.confluent","name":"Decimal_With_Scale","type":"record","fields":[{"name":"decimal","type":{"type":"bytes","precision":3,"logicalType":"decimal","scale":2}}]})
  end

  defp time_millis_json do
    ~s({"namespace":"io.confluent","name":"Time_Millis","type":"record","fields":[{"name":"time","type":{"type":"int","logicalType":"time-millis"}}]})
  end

  defp time_micros_json do
    ~s({"namespace":"io.confluent","name":"Time_Micros","type":"record","fields":[{"name":"time","type":{"type":"long","logicalType":"time-micros"}}]})
  end

  defp timestamp_millis_json do
    ~s({"namespace":"io.confluent","name":"Timestamp_Millis","type":"record","fields":[{"name":"timestamp","type":{"type":"long","logicalType":"timestamp-millis"}}]})
  end

  defp timestamp_micros_json do
    ~s({"namespace":"io.confluent","name":"Timestamp_Micros","type":"record","fields":[{"name":"timestamp","type":{"type":"long","logicalType":"timestamp-micros"}}]})
  end

  defp local_timestamp_millis_json do
    ~s({"namespace":"io.confluent","name":"Local_Timestamp_Millis","type":"record","fields":[{"name":"timestamp","type":{"type":"long","logicalType":"local-timestamp-millis"}}]})
  end

  defp local_timestamp_micros_json do
    ~s({"namespace":"io.confluent","name":"Local_Timestamp_Micros","type":"record","fields":[{"name":"timestamp","type":{"type":"long","logicalType":"local-timestamp-micros"}}]})
  end
end
