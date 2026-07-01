defmodule Avrora.Schema.Error do
  @moduledoc """
  An error describing why an Avro schema could not be parsed or loaded.

  Field `reason` names the specific failure and `path` locates the offending node
  as a dotted Avro name when known.

  See more: `Avrora.Error`
  """

  use Avrora.Error
end
