defmodule Clients do
  @moduledoc """
  This is an End-to-End integration test. It will be used to validate
  multi-client capabilities.

  So if you run `mix test` and get test errors or something like this

  ```
  could not compile dependency :avrora, "mix compile" failed
  ```

  it means that something is wrong with `Avrora.Client` module.
  """

  defmodule Alpha do
    @moduledoc false
    use Avrora.Client, schemas_path: Path.expand("../priv/schms", __DIR__)
  end

  defmodule Beta do
    @moduledoc false
    use Avrora.Client, schemas_path: Path.expand("./priv/avro")
  end
end
