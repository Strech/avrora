defmodule Avrora.AvroLogicalTypeCaster.TimeMicros do
  @moduledoc """
  TODO Write AvroLogicalTypeCaster.TimeMicros moduledoc
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
