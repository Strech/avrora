defmodule Avrora.Codec.Error do
  @moduledoc """
  An error describing why an Avro message could not be encoded or decoded.

  Field `reason` names the specific failure and `path` locates the offending field
  as a dotted Avro name when known.

  See more: `Avrora.Error`
  """

  use Avrora.Error

  @doc """
  Build an error from a raised `erlavro` encode/decode failure.

  Accepts optional `attributes` to override or add struct fields, e.g. `path` for a
  decode failure which does not carry the schema name.

  ## Examples

      iex> original = {:"$avro_encode_error", :required_field_missed, [record: "io.acme.Payment", field: "id"]}
      iex> error = Avrora.Codec.Error.from_erlavro(%ErlangError{original: original})
      iex> {error.reason, error.message, error.path}
      {:missing_field, "field `id` is required", "io.acme.Payment.id"}

      iex> error = Avrora.Codec.Error.from_erlavro(%RuntimeError{message: "boom"}, reason: :schema_mismatch)
      iex> {error.reason, error.message}
      {:schema_mismatch, "boom"}
  """
  @spec from_erlavro(Exception.t()) :: t()
  @spec from_erlavro(Exception.t(), keyword()) :: t()
  def from_erlavro(%ErlangError{original: {:"$avro_encode_error", detail, [record: record, field: field]} = original}),
    do: %{encode_error(detail, field, "#{record}.#{field}") | original: original}

  def from_erlavro(error),
    do: %__MODULE__{reason: :unknown, message: Exception.message(error), original: error}

  def from_erlavro(error, attributes), do: struct!(from_erlavro(error), attributes)

  defp encode_error(:required_field_missed, field, path),
    do: %__MODULE__{reason: :missing_field, message: "field `#{field}` is required", path: path}

  defp encode_error({:badmatch, {:error, {:type_mismatch, type, value}}}, field, path),
    do: %__MODULE__{
      reason: :type_mismatch,
      message: "field `#{field}` expected `#{:avro.get_type_name(type)}`, got `#{inspect(value)}`",
      path: path
    }


  defp encode_error(detail, _field, path),
    do: %__MODULE__{reason: :unknown, message: "encode error at `#{path}`: #{inspect(detail)}", path: path}
end
