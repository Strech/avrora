defmodule Avrora.TestCase do
  @moduledoc """
  TODO: Write documentation
  """

  alias Avrora.Storage.Memory

  @doc false
  def cleanup_storage!(_context \\ %{}) do
    ExUnit.Callbacks.on_exit(&Memory.flush/0)
  end
end
