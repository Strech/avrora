defmodule Avrora.AvroLogicalTypeCaster.Decimal do
  @moduledoc """
  The `decimal` logical type represents an arbitrary-precision signed decimal
  number of the form `unscaled × 10-scale`.

  The `decimal` logical type annotates Avro bytes or fixed types.
  The byte array must contain the two’s-complement representation
  of the unscaled integer value in big-endian byte order.

  NOTE: This module is NOT INCLUDED into defaults of `Avrora.Config` and must
        be added manually, like this

        config :avrora, logical_types_casting: %{
          "decimal" => Avrora.AvroLogicalTypeCaster.Decimal
          ...
        }

  NOTE: This module REQUIRES presence of the Decimal library, for details see
        https://hex.pm/packages/decimal
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
