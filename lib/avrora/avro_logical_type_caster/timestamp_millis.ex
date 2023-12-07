defmodule Avrora.AvroLogicalTypeCaster.TimestampMillis do
  @moduledoc """
  TODO Write AvroLogicalTypeCaster.TimestampMillis moduledoc
  """

  @behaviour Avrora.AvroLogicalTypeCaster

  alias Avrora.Errors

  @impl true
  def cast(value, _type) do
    with {:error, reason} <- DateTime.from_unix(value, :millisecond),
         do: {:error, %Errors.LogicalTypeDecodingError{code: reason}}
  end
end
