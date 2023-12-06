defmodule Avrora.AvroTypeConverter.PrimitiveIntoLogical do
  @moduledoc """
  TODO
  """

  @behaviour Avrora.AvroTypeConverter
  @unix_epoch ~D[1970-01-01]
  @logical_type "logicalType"
  @default_decimal_scale_prop {"scale", 0}
  @millisecond 1_000
  @microsecond 1_000_000
  @millisecond_precision 3
  @microsecond_precision 6

  require Logger
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

  # TODO: Introduce error class and wrap this message into it!
  # FIXME: Refactor this shit
  defp do_convert(value, type, logical_type) do
    case logical_type do
      "date" ->
        to_date(value)

      "time-millis" ->
        to_time_millis(value)

      "time-micros" ->
        to_time_micros(value)

      "decimal" ->
        <<value::signed-integer-64-big>> = value

        scale =
          :avro.get_custom_props(type)
          |> List.keyfind("scale", 0, @default_decimal_scale_prop)
          |> elem(1)

        to_decimal(value, scale)

      "uuid" ->
        {:ok, value}

      _ ->
        Logger.warning("unsupported logical type `#{logical_type}' was not converted")

        {:ok, value}
    end
  end

  defp to_date(value), do: {:ok, Date.add(@unix_epoch, value)}

  defp to_time_millis(value) do
    time =
      div(value, @millisecond)
      |> Time.from_seconds_after_midnight({rem(value, @millisecond) * 1_000, @millisecond_precision})
      |> Time.truncate(:millisecond)

    {:ok, time}
  end

  defp to_time_micros(value) do
    time =
      div(value, @microsecond)
      |> Time.from_seconds_after_midnight({rem(value, @microsecond), @microsecond_precision})

    {:ok, time}
  end

  if Code.ensure_loaded?(Decimal) do
    def to_decimal(value, 0), do: {:ok, Decimal.new(value)}

    def to_decimal(value, scale) when is_integer(value) and value > 0,
      do: {:ok, Decimal.new(1, value, -scale)}

    def to_decimal(value, scale) when is_integer(value) and value < 0,
      do: {:ok, Decimal.new(-1, -value, -scale)}
  else
    def to_decimal(_value, _scale),
      do: {:error, %Avrora.Errors.ConfigurationError{code: :missing_decimal_lib}}
  end

  defp enabled, do: Config.self().decode_logical_types() == true
end
