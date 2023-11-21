defmodule Avrora.Hook.NullValueConversion do
  @moduledoc """
  TODO
  """

  @behaviour Avrora.Hook
  @null_type_name "null"

  alias Avrora.Config

  @impl true
  def process(value, type, _sub_name_or_idx, data) do
    result = if convert() == true && :avro.get_type_name(type) == @null_type_name, do: {nil, data}, else: value

    {:ok, result}
  end

  defp convert, do: Config.self().convert_null_values()
end
