defmodule Avrora.Schema.Name do
  @moduledoc """
  Struct for versioned schema names like `io.confluent.Payment:42`.
  """

  defstruct [:name, :version]

  @type t :: %__MODULE__{
          name: String.t(),
          version: nil | integer()
        }

  @delimiter_char ":"

  @doc """
  Parse schema name with optional version, returning struct.

  ## Examples

      iex> Avrora.Schema.Name.parse("Payment")
      {:ok, %Avrora.Schema.Name{name: "Payment", version: nil}}
      iex> Avrora.Schema.Name.parse("io.confluent.Payment:42")
      {:ok, %Avrora.Schema.Name{name: "io.confluent.Payment", version: 42}}
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
