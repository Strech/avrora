defmodule Mix.Tasks.Avrora.Reg.Schema do
  use Mix.Task

  @moduledoc """
  Register either one schema or all schemas in the `Avrora.Config.schemas_path`
  directory.

  Usage:

      # Registers one schema
      mix avrora.reg.schema --name io.confluent.Payment

      # Registers all found schemas
      mix avrora.reg.schema --all
  """

  @shortdoc "Register schema(s) in the Confluent Schema Registry"

  @doc false
  @impl Mix.Task
  def run(argv) do
    IO.puts("TODO: Implement scan + register method")
  end
end
