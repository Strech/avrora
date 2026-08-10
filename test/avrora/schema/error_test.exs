defmodule Avrora.Schema.ErrorTest do
  use ExUnit.Case, async: true
  doctest Avrora.Schema.Error

  alias Avrora.Schema.Error

  describe "from_jason/2" do
    test "when a byte is unexpected it points at the line, column and character" do
      {:error, decode_error} = Jason.decode(~s({"name": nope}))
      error = Error.from_jason(~s({"name": nope}), decode_error)

      assert error.reason == :json_malformed
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

  describe "from_erlavro/1" do
    test "when a required attribute is not found" do
      original = %ErlangError{original: {:not_found, "type"}}
      error = Error.from_erlavro(original)

      assert error.reason == :attribute_missing
      assert error.message == "missing attribute `type`"
      assert error.original == original
    end

    test "when a name is invalid" do
      error = Error.from_erlavro(%ErlangError{original: {:invalid_name, "1X"}})

      assert error.reason == :name_invalid
      assert error.message == "invalid name `1X`"
    end

    test "when a type is redefined" do
      error = Error.from_erlavro(%ErlangError{original: {:type_redefined, "X"}})

      assert error.reason == :type_duplicate
      assert error.message == "duplicate type `X`"
    end

    test "when a union member is duplicated" do
      error = Error.from_erlavro(%ErlangError{original: {"duplicated union member", "string"}})

      assert error.reason == :union_member_duplicate
      assert error.message == "duplicate union member `string`"
    end

    test "when a reference is bad" do
      error = Error.from_erlavro(%MatchError{term: false})

      assert error.reason == :reference_invalid
      assert error.message == "schema contains an invalid reference"
    end

    test "when a function clause does not match" do
      error = Error.from_erlavro(%FunctionClauseError{module: :avro, function: :parse})

      assert error.reason == :schema_invalid
      assert error.message == "schema is invalid"
    end

    test "when a case clause does not match" do
      error = Error.from_erlavro(%CaseClauseError{term: :nope})

      assert error.reason == :schema_invalid
      assert error.message == "schema is invalid"
    end

    test "when the exception is not recognized" do
      original = %RuntimeError{message: "boom"}
      error = Error.from_erlavro(original)

      assert error.reason == :unknown
      assert error.message == ~s(unexpected schema error: %RuntimeError{message: "boom"})
      assert error.original == original
    end
  end
end
