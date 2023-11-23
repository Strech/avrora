defmodule Avrora.AvroTypeConverter.NullIntoNil do
  @moduledoc """
  TODO
  """

  @behaviour Avrora.AvroTypeConverter
  @null_type_name "null"

  alias Avrora.Config

  @impl true
  def convert(value, type) do
    if enabled() && :avro.get_type_name(type) == @null_type_name do
      {:ok, {nil, elem(value, 1)}}
    else
      {:ok, value}
    end
  end

  defp enabled, do: Config.self().convert_null_values() == true
end
