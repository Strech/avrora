defmodule Avrora.AvroDecoderOptions do
  @moduledoc """
  A wrapper with a bit of a login around the `:avro_binary_decoder` and
  `:avro_ocf` decoder options.
  """

  alias Avrora.AvroTypeConverter
  alias Avrora.Config

  @options %{
    encoding: :avro_binary,
    hook: &__MODULE__.__hook__/4,
    is_wrapped: true,
    map_type: :map,
    record_type: :map
  }
  # TODO Rename avro_type_converter into something better
  @type_converters [AvroTypeConverter.NullIntoNil, AvroTypeConverter.PrimitiveIntoLogical]

  @doc """
  A unified erlavro decoder options compatible for both binary and OCF decoders.
  """
  def options do
    if convert_map_to_proplist(), do: %{@options | map_type: :proplist}, else: @options
  end

  # NOTE: This is internal module function and should never be used directly
  @doc false
  def __hook__(type, sub_name_or_idx, data, decode_fun) do
    result = decoder_hook().(type, sub_name_or_idx, data, decode_fun)

    @type_converters
    |> List.foldl(result, fn type_converter, value ->
      case type_converter.convert(value, type) do
        {:ok, result} -> result
        {:error, reason} -> raise(reason)
      end
    end)
  end

  defp convert_map_to_proplist, do: Config.self().convert_map_to_proplist()
  defp decoder_hook, do: Config.self().decoder_hook()
end
