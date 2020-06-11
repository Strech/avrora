defmodule Avrora do
  @moduledoc File.read!("README.md")

  use Supervisor

  defdelegate decode(payload), to: Avrora.Encoder
  defdelegate encode(payload, opts), to: Avrora.Encoder
  defdelegate decode(payload, opts), to: Avrora.Encoder
  defdelegate extract_schema(payload), to: Avrora.Encoder

  def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

  @impl true
  def init(_state \\ []) do
    children = [
      Avrora.AvroSchemaStore,
      Avrora.Storage.Memory
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
