defmodule Avrora.AvroLogicalTypeCaster.Date do
  @moduledoc """
  TODO Write AvroLogicalTypeCaster.Date moduledoc
  """

  @behaviour Avrora.AvroLogicalTypeCaster
  @unix_epoch ~D[1970-01-01]

  @impl true
  def cast(value, _type), do: {:ok, Date.add(@unix_epoch, value)}
end
