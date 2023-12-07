defmodule Avrora.Errors do
  @moduledoc """
  TODO Write Errors moduledoc
  """

  defmodule LogicalTypeDecodingError do
    @moduledoc """
    TODO Write LogicalTypeDecodingError moduledoc
    """

    defexception [:code]

    @type t :: %__MODULE__{code: atom()}
    @messages %{
      invalid_unix_time: "given value is an invalid UNIX time",
      missing_decimal_lib: "missing `Decimal' library, see https://hex.pm/packages/decimal",
      time_zone_not_found: "configured local timezone not found in timezone database",
      utc_only_time_zone_database: "default timezone database does not support configured local timezone"
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