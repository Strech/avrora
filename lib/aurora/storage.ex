defmodule Avrora.Storage do
  @moduledoc """
  A general storage behaviour which allows a client to get the schema by a given
  name or a global ID and store a given schema under a specific name.
  """

  @callback get(key :: String.t() | integer()) ::
              {:ok, schema :: AvroEx.Schema.t()} | {:error, reason :: term()}

  @callback put(key :: String.t() | integer(), value :: map() | AvroEx.Schema.t()) ::
              {:ok, result :: term()} | {:error, reason :: term()}
end
