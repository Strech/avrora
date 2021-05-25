defmodule Avrora.Schema do
  @moduledoc """
  Convenience wrapper struct for erlavro records.
  """

  defstruct [:id, :version, :full_name, :lookup_table, :json]

  @type t :: %__MODULE__{
          id: nil | integer(),
          version: nil | integer(),
          full_name: String.t(),
          lookup_table: reference(),
          json: String.t()
        }
end
