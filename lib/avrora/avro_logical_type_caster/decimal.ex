defmodule Avrora.AvroLogicalTypeCaster.Decimal do
  @moduledoc """
  TODO Write AvroLogicalTypeCaster.Decimal moduledoc
  """

  @behaviour Avrora.AvroLogicalTypeCaster
  @default_scale_prop {"scale", 0}

  @impl true
  def cast(value, type) do
    <<value::signed-integer-64-big>> = value

    scale =
      :avro.get_custom_props(type)
      |> List.keyfind("scale", 0, @default_scale_prop)
      |> elem(1)

    {:ok, decimal(value, scale)}
  end

  defp decimal(value, 0), do: Decimal.new(value)
  defp decimal(value, scale) when value > 0, do: Decimal.new(1, value, -scale)
  defp decimal(value, scale) when value < 0, do: Decimal.new(-1, -value, -scale)
end
