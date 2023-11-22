defmodule Avrora.Hook.NullValuesConversion do
  @moduledoc """
  TODO
  """

  @behaviour Avrora.Hook
  @null_type_name "null"

  alias Avrora.Config

  @impl true
  def process(value, type, _sub_name_or_idx, data) do
    if enabled() && :avro.get_type_name(type) == @null_type_name do
      {:ok, {nil, elem(value, 1)}}
    else
      {:ok, value}
    end
  end

  defp enabled, do: Config.self().convert_null_values() == true
end
