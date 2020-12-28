defmodule Avrora.AvroDecoderOptions do
  @moduledoc """
  A wrapper with a bit of a login around the `:avro_binary_decoder` and
  `:avro_ocf` decoder options.
  """

  alias Avrora.Config

  @internal_options %{
    encoding: :avro_binary,
    hook: &__MODULE__.__hook__/4,
    is_wrapped: true
  }
  @null_type_name "null"

  @doc """
  A unified erlavro decoder options compatible for both binary and OCF decoders.
  """
  def options, do: @internal_options |> Map.merge(decoder_options())

  # NOTE: This is internal module function and should never be used directly
  @doc false
  def __hook__(type, _sub_name_or_id, data, decode_fun) do
    convert = convert_null_values()

    cond do
      convert == false -> decode_fun.(data)
      convert == true && :avro.get_type_name(type) == @null_type_name -> {nil, data}
      true -> decode_fun.(data)
    end
  end

  defp convert_null_values, do: Config.self().convert_null_values()
  defp decoder_options, do: Config.self().decoder_options()
end
