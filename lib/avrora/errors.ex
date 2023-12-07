defmodule Avrora.Errors do
  @moduledoc """
  TODO
  """

  defmodule ConfigurationError do
    @moduledoc """
    TODO
    """

    defexception [:code]

    @type t :: %__MODULE__{code: atom()}
    @messages %{
      missing_decimal_lib: "missing `Decimal' library, see https://hex.pm/packages/decimal"
    }

    @impl true
    def exception(code) when is_atom(code), do: %__MODULE__{code: code}
    def exception(_), do: %__MODULE__{}

    @impl true
    def message(%{code: code}) when is_atom(code) and code != nil,
      do: "incorrect configuration, #{Map.get(@messages, code, inspect(code))}"

    def message(_), do: "incorrect configuration"
  end

  defmodule LogicalTypeDecodingError do
    @moduledoc """
    TODO
    """

    defexception [:code]

    @type t :: %__MODULE__{code: atom()}
    @messages %{
      invalid_unix_time: "given value is an invalid Unix time"
    }

    @impl true
    def exception(code) when is_atom(code), do: %__MODULE__{code: code}
    def exception(_), do: %__MODULE__{}

    @impl true
    def message(%{code: code}) when is_atom(code) and code != nil,
      do: "logical type decoding error, #{Map.get(@messages, code, inspect(code))}"

    def message(_), do: "logical type decoding error"
  end
end
