defmodule Avrora.Codec.ErrorTest do
  use ExUnit.Case, async: true
  doctest Avrora.Codec.Error

  alias Avrora.Codec.Error

  describe "message/1" do
    test "when built with a message it returns the message" do
      error = %Error{reason: :field_missing, message: "field `amount` is required"}

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

  describe "from_erlavro/1" do
    test "when a required field is missing" do
      original = {:"$avro_encode_error", :required_field_missed, [record: "io.acme.Payment", field: "id"]}

      assert Error.from_erlavro(%ErlangError{original: original}) == %Error{
               reason: :field_missing,
               message: "field `id` is required",
               path: "io.acme.Payment.id",
               original: original
             }
    end

    test "when a field has the wrong type" do
      original =
        {:"$avro_encode_error", {:badmatch, {:error, {:type_mismatch, {:avro_primitive_type, "double", []}, "lots"}}},
         [record: "io.acme.Payment", field: "amount"]}

      assert Error.from_erlavro(%ErlangError{original: original}) == %Error{
               reason: :type_mismatch,
               message: "field `amount` expected `double`, got `\"lots\"`",
               path: "io.acme.Payment.amount",
               original: original
             }
    end

    test "when the payload does not match the schema" do
      error = %MatchError{term: <<1, 2>>}

      assert Error.from_erlavro(error) == %Error{
               reason: :schema_mismatch,
               message: "payload does not match the schema",
               original: error
             }
    end

    test "when the error is not recognized it falls back to unknown" do
      error = %RuntimeError{message: "boom"}

      assert Error.from_erlavro(error) == %Error{reason: :unknown, message: "boom", original: error}
    end
  end

  describe "from_erlavro/2" do
    test "when attributes are given they override the translated fields" do
      error = %RuntimeError{message: "boom"}

      assert Error.from_erlavro(error, reason: :schema_mismatch, path: "io.acme.Payment") == %Error{
               reason: :schema_mismatch,
               message: "boom",
               path: "io.acme.Payment",
               original: error
             }
    end

    test "when an unknown field is given it raises error" do
      assert_raise KeyError, fn -> Error.from_erlavro(%RuntimeError{message: "boom"}, bogus: 1) end
    end
  end
end
