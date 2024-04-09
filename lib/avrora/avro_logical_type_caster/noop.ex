defmodule Avrora.AvroLogicalTypeCaster.Noop do
  @moduledoc """
  This is no-op module used for unsupported logical types.
  It keeps the original value untouched and does not generate any warning.
  """

  @behaviour Avrora.AvroLogicalTypeCaster

  @impl true
  def cast(value, _type), do: {:ok, value}
end
