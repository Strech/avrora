defmodule Avrora.Schema.ErrorTest do
  use ExUnit.Case, async: true
  doctest Avrora.Schema.Error

  alias Avrora.Schema.Error

  describe "message/1" do
    test "when built with a message it returns the message" do
      error = %Error{reason: :missing_attribute, message: "field `zip` is missing `type`"}

      assert Exception.message(error) == "field `zip` is missing `type`"
    end
  end

  describe "struct" do
    test "when built it exposes reason, message, path and original" do
      error = %Error{
        reason: :unknown_type,
        message: "unknown type `strng`",
        path: "io.acme.Payment.amount",
        original: {:unknown_type, "strng"}
      }

      assert error.reason == :unknown_type
      assert error.message == "unknown type `strng`"
      assert error.path == "io.acme.Payment.amount"
      assert error.original == {:unknown_type, "strng"}
    end

    test "when path and original are omitted they default to nil" do
      error = %Error{reason: :malformed_json, message: "boom"}

      assert is_nil(error.path)
      assert is_nil(error.original)
    end
  end

  describe "raising" do
    test "when raised it behaves as an exception" do
      assert_raise Error, "boom", fn -> raise %Error{reason: :unknown, message: "boom"} end
    end
  end
end
