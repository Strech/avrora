defmodule Avrora.Hook do
  @moduledoc """
  TODO
  """

  @doc """
  TODO
  """
  @callback process(value :: term(), type :: term(), sub_name_or_idx :: term(), data :: binary()) ::
              {:ok, result :: {term(), binary()}} | {:error, reason :: term()}
end
