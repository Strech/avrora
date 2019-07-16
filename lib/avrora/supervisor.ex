defmodule Avrora.Supervisor do
  use Supervisor

  def start_link(opts \\ []) do
    IO.puts("Avrora.Supervisor.start_link/1")
    IO.puts(inspect(opts))

    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def init(state \\ []) do
    IO.puts("Avrora.Supervisor.init/1")
    IO.puts(inspect(state))

    children = [
      Avrora.Storage.Memory
    ]

    Supervisor.start_link(children, strategy: :one_for_one)
  end
end
