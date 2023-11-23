defmodule Avrora.AvroTypeConverter.PrimitiveIntoLogical do
  @moduledoc """
  TODO
  """

  @behaviour Avrora.AvroTypeConverter
  @unix_epoch ~D[1970-01-01]
  @logical_type "logicalType"

  alias Avrora.Config

  @impl true
  def convert(value, type) do
    with true <- enabled(),
         {@logical_type, logical_type} <- :avro.get_custom_props(type) |> List.keyfind(@logical_type, 0),
         {value, rest} <- value,
         {:ok, converted} <- do_convert(value, logical_type) do
      {:ok, {converted, rest}}
    else
      {:error, reason} -> {:error, reason}
      _ -> {:ok, value}
    end
  end

  # Supported logical types:
  #   1. Date
  #   2 ...
  #   TODO: Introduce error class and wrap this message into it!
  defp do_convert(value, type) do
    case type do
      "Date" -> {:ok, to_date(value)}
      _ -> {:error, "unknown logical type `#{type}'"}
    end
  end

  defp to_date(value), do: Date.add(@unix_epoch, value)
  defp enabled, do: Config.self().decode_logical_types() == true
end
