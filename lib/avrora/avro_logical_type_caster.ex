defmodule Avrora.AvroLogicalTypeCaster do
  @moduledoc """
  TODO Write AvroLogicalTypeCaster moduledoc
  """

  @doc """
  TODO Write convert callback doc

  NOTE that type is an erlavro type
       and we are converting erlang/avro types into Elixir
  """
  @callback cast(value :: term(), type :: term()) ::
              {:ok, result :: term()} | {:error, reason :: Exception.t() | term()}
end
