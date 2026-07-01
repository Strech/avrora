defmodule Avrora.Codec.ErrorTest do
  use ExUnit.Case, async: true
  doctest Avrora.Codec.Error

  alias Avrora.Codec.Error

  describe "message/1" do
    test "when built with a message it returns the message" do
      error = %Error{reason: :missing_field, message: "field `amount` is required"}

      assert Exception.message(error) == "field `amount` is required"
    end
  end

  describe "struct" do
    test "when built it exposes reason, message, path and original" do
      error = %Error{
        reason: :type_mismatch,
        message: "field `amount` expected `double`, got `\"lots\"`",
        path: "io.acme.Payment.amount",
        original: {:type_mismatch, "double", "lots"}
      }

      assert error.reason == :type_mismatch
      assert error.message == "field `amount` expected `double`, got `\"lots\"`"
      assert error.path == "io.acme.Payment.amount"
      assert error.original == {:type_mismatch, "double", "lots"}
    end

    test "when path and original are omitted they default to nil" do
      error = %Error{reason: :schema_mismatch, message: "boom"}

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
