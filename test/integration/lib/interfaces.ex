defmodule Interfaces do
  @moduledoc """
  This is an End-to-End integration test. All the public interface use cases
  will be listed here to catch the discrepancy in typespecs.

  So if you run `mix dialyzer` and receive something like this

      ```
      lib/integration.ex:41:no_return
      Function encode_with_two_options/0 has no local return.
      ```

  it means that somewhere happen an error and the outcome of it is not specified
  anywhere in the typespec of the test function.

  In other words either the code in the library is wrong or its typespec.
  """

  defmodule Test do
    @moduledoc false

    @doc false
    def extract_schema_with_no_options do
      Avrora.extract_schema(<<2, 118>>)
    end

    @doc false
    def decode_with_no_options do
      Avrora.decode(<<2, 118>>)
    end

    @doc false
    def decode_with_one_option do
      Avrora.decode(<<2, 118>>, schema_name: "avrora.Record")
    end

    @doc false
    def decode_plain_with_one_option do
      Avrora.decode(<<2, 118>>, schema_name: "avrora.Record")
    end

    @doc false
    def encode_with_one_option do
      Avrora.encode(%{"k" => "v"}, schema_name: "avrora.Record")
    end

    @doc false
    def encode_with_two_options do
      Avrora.encode(%{"k" => "v"}, schema_name: "avrora.Record", format: :plain)
    end

    # doc false
    def encode_plain_with_one_option do
      Avrora.encode_plain(%{"k" => "v"}, schema_name: "avrora.Record")
    end
  end
end
