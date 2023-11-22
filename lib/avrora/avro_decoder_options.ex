defmodule Avrora.AvroDecoderOptions do
  @moduledoc """
  A wrapper with a bit of a login around the `:avro_binary_decoder` and
  `:avro_ocf` decoder options.
  """

  alias Avrora.Config
  alias Avrora.Hook

  @options %{
    encoding: :avro_binary,
    hook: &__MODULE__.__hook__/4,
    is_wrapped: true,
    map_type: :map,
    record_type: :map
  }
  @hooks [Hook.NullValuesConversion, Hook.LogicalTypesConversion]

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

    @hooks
    |> List.foldl(result, fn hook, result ->
      case hook.process(result, type, sub_name_or_idx, data) do
        {:ok, res} -> res
        {:error, reason} -> raise(reason)
      end
    end)
  end

  defp convert_map_to_proplist, do: Config.self().convert_map_to_proplist()
  defp decoder_hook, do: Config.self().decoder_hook()
end
