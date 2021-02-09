defmodule Fixtures do
  @moduledoc """
  This is an End-to-End integration use-case. It will validate multi-client capabilities.

  So if you run `mix test` and get test errors or something like this

  ```
  could not compile dependency :avrora, "mix compile" failed
  ```

  it means that something is wrong with `Avrora.Client` module.
  """

  defmodule Alpha do
    @moduledoc false
    use Avrora.Client, schemas_path: Path.expand("./test/fixtures/schms")
  end

  defmodule Beta do
    @moduledoc false
    use Avrora.Client, schemas_path: Path.expand("./test/fixtures/avro")
  end
end
