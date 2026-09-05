defmodule Avrora.ErrorTest do
  use ExUnit.Case, async: true
  doctest Avrora.Error

  defmodule SampleError do
    use Avrora.Error
  end

  describe "message/1" do
    test "when built with a message it returns the message" do
      error = %SampleError{reason: :boom, message: "kaboom"}

      assert Exception.message(error) == "kaboom"
    end
  end

  describe "struct" do
    test "when built it exposes reason, message, path and original" do
      error = %SampleError{reason: :boom, message: "kaboom", path: "io.acme.Payment", original: :raw}

      assert error.reason == :boom
      assert error.message == "kaboom"
      assert error.path == "io.acme.Payment"
      assert error.original == :raw
    end

    test "when path and original are omitted they default to nil" do
      error = %SampleError{reason: :boom, message: "kaboom"}

      assert is_nil(error.path)
      assert is_nil(error.original)
    end
  end

  describe "raising" do
    test "when raised it behaves as an exception" do
      assert_raise SampleError, "kaboom", fn -> raise %SampleError{reason: :boom, message: "kaboom"} end
    end
  end
end
