defmodule Avrora.Schema.ErrorTest do
  use ExUnit.Case, async: true
  doctest Avrora.Schema.Error

  alias Avrora.Schema.Error

  describe "from_jason/2" do
    test "when a byte is unexpected it points at the line, column and character" do
      {:error, decode_error} = Jason.decode(~s({"name": nope}))
      error = Error.from_jason(~s({"name": nope}), decode_error)

      assert error.reason == :malformed_json
      assert error.message == ~S/malformed JSON at line 1, column 10 (unexpected "n")/
      assert error.original == decode_error
    end

    test "when the payload is multiline it counts the line and column" do
      {:error, decode_error} = Jason.decode(~s/{\n  "a": 1,\n  bad\n}/)
      error = Error.from_jason(~s/{\n  "a": 1,\n  bad\n}/, decode_error)

      assert error.message == ~S/malformed JSON at line 3, column 3 (unexpected "b")/
    end

    test "when the payload ends early it reports end of input" do
      {:error, decode_error} = Jason.decode(~s({"a":1))
      error = Error.from_jason(~s({"a":1), decode_error)

      assert error.message == "malformed JSON at line 1, column 7 (unexpected end of input)"
    end
  end
end
