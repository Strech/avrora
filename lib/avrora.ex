defmodule Avrora do
  @moduledoc File.read!("README.md") |> String.replace("/assets", "assets")

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
