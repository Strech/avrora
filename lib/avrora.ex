defmodule Avrora do
  @moduledoc File.read!("README.md")

  use Application

  defdelegate encode(payload, opts), to: Avrora.Encoder
  defdelegate decode(payload, opts), to: Avrora.Encoder

  def start(type, args) do
    IO.puts("Avrora.start/2")
    IO.puts(inspect(type))
    IO.puts(inspect(args))

    Avrora.Supervisor.start_link(name: :avrora)
  end
end
