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

  defp do_convert2(value, type, logical_type) do
    Map.get(@config, logical_type, Map.fetch!(@config, "_")).cast(value, type)
  end

  # FIXME: Refactor this shit
  defp do_convert(value, type, logical_type) do
    case logical_type do
      "local-timestamp-millis" -> to_local_timestamp_millis(value)
      "local-timestamp-micros" -> to_local_timestamp_micros(value)
      _ -> do_convert2(value, type, logical_type)
    end
  end

  defp to_local_timestamp_millis(value) do
    with {:ok, date_time} <- DateTime.from_unix(value, :millisecond),
         {:ok, local_date_time} <- DateTime.shift_zone(date_time, "Japan") do
      {:ok, local_date_time}
    else
      {:error, reason} -> {:error, %Avrora.Errors.LogicalTypeDecodingError{code: reason}}
    end
  end

  defp to_local_timestamp_micros(value) do
    with {:ok, date_time} <- DateTime.from_unix(value, :microsecond),
         {:ok, local_date_time} <- DateTime.shift_zone(date_time, "Japan") do
      {:ok, local_date_time}
    else
      {:error, reason} -> {:error, %Avrora.Errors.LogicalTypeDecodingError{code: reason}}
    end
  end

  defp enabled, do: Config.self().cast_logical_types() == true
end
