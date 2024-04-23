# TODO Merge into type caster and remove list handling in decoder options
defmodule Avrora.AvroTypeConverter.PrimitiveIntoLogical do
  @moduledoc """
  TODO Write PrimitiveIntoLogical moduledoc
  """

  @behaviour Avrora.AvroTypeConverter

  @logical_type "logicalType"

  alias Avrora.AvroLogicalTypeCaster
  alias Avrora.Config

  @impl true
  def convert(value, type) do
    with true <- enabled(),
         {@logical_type, logical_type} <- :avro.get_custom_props(type) |> List.keyfind(@logical_type, 0),
         {value, rest} <- value,
         {:ok, converted} <- do_convert(value, type, logical_type) do
      {:ok, {converted, rest}}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:ok, value}
    end
  end

  # TODO Remove and replace with config
  # TODO Add support module to test Japan timezone in local timestamp
  @config %{
    "uuid" => AvroLogicalTypeCaster.Noop,
    "date" => AvroLogicalTypeCaster.Date,
    "decimal" => AvroLogicalTypeCaster.Decimal,
    "time-millis" => AvroLogicalTypeCaster.TimeMillis,
    "time-micros" => AvroLogicalTypeCaster.TimeMicros,
    "timestamp-millis" => AvroLogicalTypeCaster.TimestampMillis,
    "timestamp-micros" => AvroLogicalTypeCaster.TimestampMicros,
    "local-timestamp-millis" => AvroLogicalTypeCaster.LocalTimestampMillis,
    "local-timestamp-micros" => AvroLogicalTypeCaster.LocalTimestampMicros,
    "_" => AvroLogicalTypeCaster.NoopWarning
  }

  # TODO Replace fetch! with fetch and raise generic error of Avrora
  defp do_convert(value, type, logical_type) do
    Map.get(@config, logical_type, Map.fetch!(@config, "_")).cast(value, type)
  end

  defp enabled, do: Config.self().cast_logical_types() == true
end
