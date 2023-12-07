defmodule Avrora.AvroLogicalTypeCaster.Noop do
  @moduledoc """
  TODO Write AvroLogicalTypeCaster.Noop moduledoc
  """

  @behaviour Avrora.AvroLogicalTypeCaster

  @impl true
  def cast(value, _type), do: {:ok, value}
end
