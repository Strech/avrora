defmodule Avrora.Storage do
  @moduledoc """
  A general storage behaviour which allows a client to get the schema by a given
  name or a global ID and store a given schema under a specific name.
  """

  @typedoc """
  A possible schema indentifier.
  """
  @type schema_id :: String.t() | integer()

  @callback get(key :: schema_id) ::
              {:ok, result :: nil | Avrora.Schema.t()} | {:error, reason :: term()}

  @callback put(key :: schema_id, value :: Avrora.Schema.t()) ::
              {:ok, result :: Avrora.Schema.t()} | {:error, reason :: term()}

  defmodule Transient do
    @moduledoc """
    A type of storage which allows keys to be removed or expired.
    """

    alias Avrora.Storage

    @typedoc """
    A naive timestamp with a seconds precision.
    """
    @type timestamp :: timeout()

    @callback delete(key :: Storage.schema_id()) ::
                {:ok, result :: boolean()} | {:error, reason :: term()}

    @callback expire(key :: Storage.schema_id(), ttl :: timeout()) ::
                {:ok, timestamp :: timestamp()} | {:error, reason :: term()}
  end
end
