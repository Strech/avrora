defmodule Avrora.AvroLogicalTypeCaster.Date do
  @moduledoc """
  The `date` logical type represents a date within the calendar,
  with no reference to a particular time zone or time of day.

  The `date` logical type annotates an Avro `int`, where the `int` stores
  the number of days from the unix epoch, 1 January 1970 (ISO calendar).
  """

  @behaviour Avrora.AvroLogicalTypeCaster
  @unix_epoch ~D[1970-01-01]

  @impl true
  def cast(value, _type), do: {:ok, Date.add(@unix_epoch, value)}
end
