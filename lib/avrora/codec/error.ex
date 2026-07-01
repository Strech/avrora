defmodule Avrora.Codec.Error do
  @moduledoc """
  An error describing why an Avro message could not be encoded or decoded.

  Field `reason` names the specific failure and `path` locates the offending field
  as a dotted Avro name when known.

  See more: `Avrora.Error`
  """

  use Avrora.Error
end
