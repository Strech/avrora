defmodule Avrora.Error do
  @moduledoc """
  Common shape and behaviour shared by all Avrora errors.

  An error carries a machine-matchable `reason`, a human-readable `message`, an
  optional dotted Avro `path` to the offending node and the `original` underlying
  term it was built from.

  ## Examples

      iex> error = %Avrora.Schema.Error{reason: :malformed_json, message: "invalid JSON"}
      iex> Exception.message(error)
      "invalid JSON"

      iex> error =
      ...>   %Avrora.Schema.Error{
      ...>     reason: :unknown_type,
      ...>     message: "unknown type `strng`",
      ...>     path: "io.acme.Payment.amount",
      ...>     original: {:unknown_type, "strng"}
      ...>   }
      iex> {error.reason, error.path}
      {:unknown_type, "io.acme.Payment.amount"}
  """

  @doc false
  defmacro __using__(_opts) do
    quote do
      defexception [:reason, :message, :path, :original]

      @type t :: %__MODULE__{
              reason: atom(),
              message: String.t(),
              path: String.t() | nil,
              original: term()
            }

      @impl true
      def message(%__MODULE__{message: message}), do: message
    end
  end
end
