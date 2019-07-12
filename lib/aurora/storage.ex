defmodule Avrora.Storage do
  @moduledoc """
  A general storage behaviour which allows a client to get the schema by a given
  name or a global ID and store a given schema under a specific name.
  """

  @callback get(key :: String.t() | integer()) ::
              {:ok, result :: nil | Avrora.Schema.t()} | {:error, reason :: term()}

  # TODO: Check that map() is really needed and remove it from examples
  # TODO: Make value :: Avrora.Schema.t() only?
  @callback put(key :: String.t() | integer(), value :: String.t() | map() | Avrora.Schema.t()) ::
              {:ok, result :: Avrora.Schema.t()} | {:error, reason :: term()}
end
