defmodule Avrora.AvroLogicalTypeCaster.NoopWarning do
  @moduledoc """
  TODO Write AvroLogicalTypeCaster.NoopWarning moduledoc
  """

  @behaviour Avrora.AvroLogicalTypeCaster

  require Logger

  @impl true
  def cast(value, type) do
    {_, logical_type} = :avro.get_custom_props(type) |> List.keyfind("logicalType", 0)
    Logger.warning("unsupported logical type `#{logical_type}', its value was not type casted")

    {:ok, value}
  end
end
