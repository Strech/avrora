defmodule Avrora.AvroLogicalTypeCaster.TimestampMicros do
  @moduledoc """
  TODO Write AvroLogicalTypeCaster.TimestampMicros moduledoc
  """

  @behaviour Avrora.AvroLogicalTypeCaster

  alias Avrora.Errors

  @impl true
  def cast(value, _type) do
    with {:error, reason} <- DateTime.from_unix(value, :microsecond),
         do: {:error, %Errors.LogicalTypeDecodingError{code: reason}}
  end
end
