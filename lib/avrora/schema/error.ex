defmodule Avrora.Schema.Error do
  @moduledoc """
  An error describing why an Avro schema could not be parsed or loaded.

  Field `reason` names the specific failure and `path` locates the offending node
  as a dotted Avro name when known.

  See more: `Avrora.Error`
  """

  use Avrora.Error

  @doc """
  Build an error from a `Jason` JSON decode failure, pointing at the offending
  line, column and character.

  ## Examples

      iex> json = ~s({"name": nope})
      iex> {:error, decode_error} = Jason.decode(json)
      iex> error = Avrora.Schema.Error.from_jason(json, decode_error)
      iex> {error.reason, error.message}
      {:json_malformed, ~s/malformed JSON at line 1, column 10 (unexpected "n")/}
  """
  @spec from_jason(String.t(), Jason.DecodeError.t()) :: t()
  def from_jason(payload, %Jason.DecodeError{position: position} = error) do
    {line, column} = calculate_line_and_column(payload, position)

    unexpected =
      if position < byte_size(payload),
        do: ~s("#{binary_part(payload, position, 1)}"),
        else: "end of input"

    %__MODULE__{
      reason: :json_malformed,
      message: "malformed JSON at line #{line}, column #{column} (unexpected #{unexpected})",
      original: error
    }
  end

  defp calculate_line_and_column(payload, position) do
    newlines = :binary.matches(binary_part(payload, 0, position), "\n")

    last_newline =
      case List.last(newlines) do
        {index, _length} -> index
        nil -> -1
      end

    {length(newlines) + 1, position - last_newline}
  end
end
