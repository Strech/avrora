defmodule Avrora.Name do
  @moduledoc """
  A wrapper around versioned name the schema. It can handle names like `io.confluent.Payment`
  and `io.confluent.Payment:42` by using `:` as a delimiter.
  """

  defstruct [:name, :version]

  @type t :: %__MODULE__{
          name: String.t(),
          version: nil | integer()
        }

  @delimiter_char ":"

  @doc """
  Parses given name and plits it on `name` + `version` by a `:` delimiter.

  ## Examples

      iex> Avrora.Name.parse("Payment")
      {:ok, %Avrora.Name{name: "Payment", version: nil}}
      iex> Avrora.Name.parse("io.confluent.Payment:42")
      {:ok, %Avrora.Name{name: "io.confluent.Payment", version: 42}}
  """
  @spec parse(String.t()) :: {:ok, t()} | {:error, term()}
  def parse(payload) when is_binary(payload) do
    with parts <- String.split(payload, @delimiter_char, parts: 2) do
      version = Enum.at(parts, 1)

      version =
        if is_binary(version) do
          case Integer.parse(version) do
            {version, _} -> version
            _ -> nil
          end
        end

      {:ok, %__MODULE__{name: Enum.at(parts, 0), version: version}}
    end
  end
end
