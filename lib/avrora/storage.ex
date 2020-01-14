defmodule Avrora.Storage do
  @moduledoc """
  Behavior for storing and getting schemas by name or integer ID.
  """

  @typedoc "Schema indentifier."
  @type schema_id :: String.t() | integer()

  @callback get(key :: schema_id) ::
              {:ok, result :: nil | Avrora.Schema.t()} | {:error, reason :: term()}

  @callback put(key :: schema_id, value :: Avrora.Schema.t()) ::
              {:ok, result :: Avrora.Schema.t()} | {:error, reason :: term()}

  defmodule Transient do
    @moduledoc """
    Storage behavior which allows keys to be removed or expired.
    """

    alias Avrora.Storage

    @typedoc "Naive timestamp with second precision."
    @type timestamp :: timeout()

    @callback delete(key :: Storage.schema_id()) ::
                {:ok, result :: boolean()} | {:error, reason :: term()}

    @callback expire(key :: Storage.schema_id(), ttl :: timeout()) ::
                {:ok, timestamp :: timestamp()} | {:error, reason :: term()}

    @callback flush() :: {:ok, result :: boolean()} | {:error, reason :: term()}
  end
end
