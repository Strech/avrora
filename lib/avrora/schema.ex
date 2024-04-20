defmodule Avrora.Schema do
  @moduledoc """
  Convenience wrapper struct for erlavro records.
  """

  defstruct [:id, :version, :full_name, :lookup_table, :json, :source]

  @type t :: %__MODULE__{
          id: nil | integer(),
          version: nil | integer(),
          full_name: String.t(),
          lookup_table: reference(),
          json: String.t(),
          # TODO: Remove nil, maybe call it `source_json`
          source: nil | String.t()
        }
end
