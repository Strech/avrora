defmodule Avrora.TestCase do
  @moduledoc """
  An ExUnit helper.
  """

  alias Avrora.Storage.Memory

  @doc """
    A hook function to be used in `setup`-hook to clean memory storage.

    ## Examples:

        defmodule MyTest do
          use ExUnit.Case, async: true

          import Avrora.TestCase
          setup :cleanup_storage!

          test "memory storage was filled" do
            asset Avrora.Storage.Memory.get("some") == nil

            Avrora.Storage.Memory.put("some", 42)
            asset Avrora.Storage.Memory.get("some") == 42
          end

          test "memory storage is clean" do
            asset Avrora.Storage.Memory.get("some") == nil
          end
        end
  """
  def cleanup_storage!(_context \\ %{}) do
    ExUnit.Callbacks.on_exit(&Memory.flush/0)
  end
end
