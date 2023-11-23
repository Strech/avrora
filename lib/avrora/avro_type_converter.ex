defmodule Avrora.AvroTypeConverter do
  @moduledoc """
  TODO
  """

  @doc """
  TODO

  NOTE that type is an erlavro type
       and we are converting erlang/avro types into Elixir
  """
  @callback convert(value :: term(), type :: term()) :: {:ok, result :: {term(), binary()}} | {:error, reason :: term()}
end
