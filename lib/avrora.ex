defmodule Avrora do
  @moduledoc """
  A library created with a huge influence of [AvroTurf](https://github.com/dasch/avro_turf)
  to encode and decode AVRO messages.

  It's able to use locally stored schemas with in memory cache, but also it can
  use Confluent Schema Registry to fetch and register new schemas without big effort
  from user side.

  ## Examples

      ...> {:ok, _} = Avrora.start_link([])
      {:ok, #PID<0.196.0>}
      ...> message = %{"id" => "tx-1", "amount" => 15.99}
      %{"id" => "tx-1", "amount" => 15.99}
      ...> encoded = Avrora.encode(message, schema_name: "io.confluent.Payment")
      {:ok, <<8, 116, 120, 45, 49, 123, 20, 174, 71, 225, 250, 47, 64>>}
      ...> decoded = Avrora.encode(encoded, schema_name: "io.confluent.Payment")
      {:ok, %{"id" => "tx-1", "amount" => 15.99}}
  """

  use Supervisor

  defdelegate encode(payload, opts), to: Avrora.Encoder
  defdelegate decode(payload, opts), to: Avrora.Encoder

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(_state \\ []) do
    children = [
      Avrora.Storage.Memory
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
