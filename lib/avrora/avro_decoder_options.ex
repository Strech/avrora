defmodule Avrora.AvroDecoderOptions do
  @moduledoc """
  A wrapper with a bit of a login around the `:avro_binary_decoder` and
  `:avro_ocf` decoder options.
  """

  alias Avrora.Config

  @options %{
    encoding: :avro_binary,
    hook: &__MODULE__.__hook__/4,
    is_wrapped: true,
    map_type: :map,
    record_type: :map
  }
  @null_type_name "null"

  @doc """
  A unified erlavro decoder options compatible for both binary and OCF decoders.
  """
  def options do
    if convert_map_to_proplist(), do: %{@options | map_type: :proplist}, else: @options
  end

  # NOTE: This is internal module function and should never be used directly
  @doc false
  def __hook__(type, sub_name_or_idx, data, decode_fun) do
    convert = convert_null_values()
    decode_hook = decode_hook()

    result = decode_hook.(type, sub_name_or_idx, data, decode_fun)

    if convert == true && :avro.get_type_name(type) == @null_type_name,
      do: {nil, data},
      else: result
  end

  defp convert_null_values, do: Config.self().convert_null_values()
  defp convert_map_to_proplist, do: Config.self().convert_map_to_proplist()
  defp decode_hook, do: Config.self().decode_hook()
end
