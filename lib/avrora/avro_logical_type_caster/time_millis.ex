defmodule Avrora.AvroLogicalTypeCaster.TimeMillis do
  @moduledoc """
  TODO Write AvroLogicalTypeCaster.TimeMillis moduledoc
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
