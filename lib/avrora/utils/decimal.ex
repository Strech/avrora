defmodule Avrora.Utils.Decimal do
  @moduledoc """
  TODO
  """

  @doc """
  TODO
  """
  if Code.ensure_loaded?(Decimal) do
    def new(value, 0), do: {:ok, Decimal.new(value)}
    def new(value, scale), do: {:ok, %{Decimal.new(value) | exp: -scale}}
  else
    def cast(_value, _scale), do: {:error, :missing_decimal_module}
  end
end
