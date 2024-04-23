defmodule Avrora.AvroLogicalTypeCaster.TimeMillis do
  @moduledoc """
  The `time-millis` logical type represents a time of day, with no reference to
  a particular calendar, time zone or date, with a precision of one millisecond.

  The `time-millis` logical type annotates an Avro `int`, where the `int` stores
  the number of milliseconds after midnight, 00:00:00.000.
  """

  @behaviour Avrora.AvroLogicalTypeCaster
  @milliseconds 1_000
  @precision 3

  @impl true
  def cast(value, _type) do
    time =
      div(value, @milliseconds)
      |> Time.from_seconds_after_midnight({rem(value, @milliseconds) * 1_000, @precision})
      |> Time.truncate(:millisecond)

    {:ok, time}
  end
end
