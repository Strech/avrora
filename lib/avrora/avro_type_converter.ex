defmodule Avrora.AvroTypeConverter do
  @moduledoc """
  TODO Write AvroTypeConverter moduledoc
  """

  @doc """
  TODO Write convert callback doc

  NOTE that type is an erlavro type
       and we are converting erlang/avro types into Elixir
  """
  @callback convert(value :: term(), type :: term()) :: {:ok, result :: {term(), binary()}} | {:error, reason :: term()}
end
