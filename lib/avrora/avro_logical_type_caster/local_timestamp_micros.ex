defmodule Avrora.AvroLogicalTypeCaster.LocalTimestampMicros do
  @moduledoc """
  TODO Write AvroLogicalTypeCaster.LocalTimestampMicros moduledoc
  """

  @behaviour Avrora.AvroLogicalTypeCaster
  # @timezone "Etc/UTC"
  @timezone "Japan"

  alias Avrora.Errors

  @impl true
  def cast(value, _type) do
    with {:ok, date_time} <- DateTime.from_unix(value, :microsecond),
         {:ok, local_date_time} <- DateTime.shift_zone(date_time, @timezone) do
      {:ok, local_date_time}
    else
      {:error, reason} -> {:error, %Errors.LogicalTypeDecodingError{code: reason}}
    end
  end
end
