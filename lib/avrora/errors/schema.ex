defmodule Avrora.Errors.Schema do
  @moduledoc """
  An error explaining why an Avro schema could not be used.

  See more: `Avrora.Error`
  """

  use Avrora.Error

  @doc """
  Build an error from a `Jason` JSON decode failure, pointing at the offending
  line, column and character.

  ## Examples

      iex> json = ~s({"name": nope})
      iex> {:error, decode_error} = Jason.decode(json)
      iex> error = Avrora.Errors.Schema.from_jason(json, decode_error)
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

  @doc """
  Build an error from an exception raised by `erlavro`.

  ## Examples

      iex> error = Avrora.Errors.Schema.from_erlavro(%ErlangError{original: {:not_found, "type"}})
      iex> {error.reason, error.message}
      {:attribute_missing, "missing attribute `type`"}
  """
  @spec from_erlavro(Exception.t()) :: t()
  def from_erlavro(%ErlangError{original: {:not_found, attribute}} = error),
    do: %__MODULE__{reason: :attribute_missing, message: "missing attribute `#{attribute}`", original: error}

  def from_erlavro(%ErlangError{original: {:invalid_name, name}} = error),
    do: %__MODULE__{reason: :name_invalid, message: "invalid name `#{name}`", original: error}

  def from_erlavro(%ErlangError{original: {:type_redefined, name}} = error),
    do: %__MODULE__{reason: :type_duplicate, message: "duplicate type `#{name}`", original: error}

  def from_erlavro(%ErlangError{original: {"duplicated union member", member}} = error),
    do: %__MODULE__{reason: :union_member_duplicate, message: "duplicate union member `#{member}`", original: error}

  def from_erlavro(%MatchError{} = error),
    do: %__MODULE__{reason: :reference_invalid, message: "schema contains an invalid reference", original: error}

  def from_erlavro(%FunctionClauseError{} = error),
    do: %__MODULE__{reason: :schema_invalid, message: "schema is invalid", original: error}

  def from_erlavro(%CaseClauseError{} = error),
    do: %__MODULE__{reason: :schema_invalid, message: "schema is invalid", original: error}

  def from_erlavro(error),
    do: %__MODULE__{reason: :unknown, message: "unexpected schema error: #{inspect(error)}", original: error}

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
