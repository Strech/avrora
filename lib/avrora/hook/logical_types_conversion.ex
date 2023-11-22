defmodule Avrora.Hook.LogicalTypesConversion do
  @moduledoc """
  TODO
  """

  @behaviour Avrora.Hook
  @unix_epoch ~D[1970-01-01]
  @logical_type "logicalType"

  alias Avrora.Config

  @impl true
  def process(value, type, _sub_name_or_idx, data) do
    if enabled() do
      case :avro.get_custom_props(type) |> List.keyfind(@logical_type, 0) do
        {@logical_type, logical_type} ->
          with {:ok, val} <- convert(elem(value, 0), logical_type),
               rest <- elem(value, 1) do
            {:ok, {val, rest}}
          end

        _ ->
          {:ok, value}
      end
    else
      {:ok, value}
    end
  end

  # Supported logical types:
  #   1. Date
  #   2 ...
  #   TODO: make conversion into some logical types with dates first
  defp convert(value, type) do
    case type do
      "Date" -> {:ok, to_date(value)}
      _ -> {:error, "unknown logical type `#{type}'"}
    end
  end

  defp to_date(value), do: Date.add(@unix_epoch, value)
  defp enabled, do: Config.self().convert_logical_types() == true
end
