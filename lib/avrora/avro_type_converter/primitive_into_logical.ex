defmodule Avrora.AvroTypeConverter.PrimitiveIntoLogical do
  @moduledoc """
  TODO
  """

  @behaviour Avrora.AvroTypeConverter
  @unix_epoch ~D[1970-01-01]
  @logical_type "logicalType"
  @default_decimal_scale_prop {"scale", 0}

  alias Avrora.Config
  alias Avrora.Utils

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

  # Supported logical types:
  # Unsupported logical types: Decimal, Duration
  #   1. Date
  #   2 ...
  #   TODO: Introduce error class and wrap this message into it!
  #
  #   Fixed = value * 10^-scale
  #   https://hexdocs.pm/decimal/Decimal.html#new/3 = sign * coefficient * 10 ^ exponent
  #
  #   {:avro_fixed_type, "money", "", [], 5, "io.confluent.money",
  #      [{"logicalType", "Decimal"}]}
  #
  #   {:avro_primitive_type, "bytes",
  #      [{"precision", 3}, {"logicalType", "Decimal"}, {"scale", 2}]}
  defp do_convert(value, type, logical_type) do
    case logical_type do
      "Date" ->
        to_date(value)

      "Decimal" ->
        <<value::signed-integer-64-big>> = value

        scale =
          :avro.get_custom_props(type)
          |> List.keyfind("scale", 0, @default_decimal_scale_prop)
          |> elem(1)

        Utils.Decimal.new(value, scale)

      "UUID" ->
        {:ok, value}

      _ ->
        # TODO: Maybe I should warn and return as is?
        {:error, "unknown logical type `#{logical_type}'"}
    end
  end

  defp to_date(value), do: {:ok, Date.add(@unix_epoch, value)}
  defp enabled, do: Config.self().decode_logical_types() == true
end
