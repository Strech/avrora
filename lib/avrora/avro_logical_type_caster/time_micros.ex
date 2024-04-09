defmodule Avrora.AvroLogicalTypeCaster.TimeMicros do
  @moduledoc """
  The `time-micros` logical type represents a time of day, with no reference to
  a particular calendar, time zone or date, with a precision of one microsecond.

  The `time-micros` logical type annotates an Avro `long`, where the `long`
  stores the number of microseconds after midnight, 00:00:00.000000.
  """

  @behaviour Avrora.AvroLogicalTypeCaster
  @microseconds 1_000_000
  @precision 6

  @impl true
  def cast(value, _type) do
    time =
      div(value, @microseconds)
      |> Time.from_seconds_after_midnight({rem(value, @microseconds), @precision})

    {:ok, time}
  end
end
