# Avrora

Elixir library for encoding/decoding Avro messages with Confluent Schema Registry and local schema file support.

## Commands

- `mix test` — run tests
- `mix format` — format code
- `mix format --check-formatted` — check formatting
- `mix credo --strict` — lint
- `mix dialyzer` — type check
- `mix check` — run all checks (coveralls + dialyzer + credo)

## Project structure

```
lib/
  avrora.ex                          # Main supervisor, delegates to Encoder
  avrora/
    client.ex                        # Macro for private isolated clients (`use Avrora.Client`)
    config.ex                        # Configuration callbacks with defaults
    encoder.ex                       # Public API: encode/decode with format detection
    resolver.ex                      # Schema resolution with caching (memory → registry → file)
    schema.ex                        # Schema struct definition
    http_client.ex                   # Minimal HTTP wrapper over :httpc
    avro_schema_store.ex             # Erlang avro schema store wrapper
    avro_decoder_options.ex          # Decoder options struct
    test_case.ex                     # ExUnit case template for testing
    codec.ex                         # Codec behaviour definition
    codec/
      plain.ex                       # Raw Avro binary codec
      schema_registry.ex             # Confluent wire format codec (schema ID prefix)
      object_container_file.ex       # OCF format codec (embedded schema)
    schema/
      encoder.ex                     # JSON ↔ erlavro type conversion
      name.ex                        # Schema name parser (name:version)
      reference_collector.ex         # Collects schema references for registration
    storage.ex                       # Storage behaviour definition
    storage/
      file.ex                        # Read schemas from filesystem
      memory.ex                      # ETS-based in-memory cache with TTL
      registry.ex                    # Confluent Schema Registry HTTP client
    utils/
      registrar.ex                   # Schema registration utility
  mix/tasks/
    avrora.reg.schema.ex             # Mix task for schema registration

test/
  avrora/                            # Unit tests mirror lib/ structure
  integration/                       # Integration test project
  fixtures/                          # Avro schema files (.avsc) for tests
  support/                           # Test helpers and mocks
  mix/tasks/                         # Mix task tests

config/config.exs                    # Mix configuration
priv/plts/                           # Dialyzer PLT cache
```

## Testing styleguide

### File structure

```elixir
defmodule Avrora.SomeModuleTest do
  use ExUnit.Case, async: true
  doctest Avrora.SomeModule

  import Mox
  import Support.Config
  import ExUnit.CaptureLog
  alias Avrora.{Schema, ...}

  setup :verify_on_exit!
  setup :support_config

  describe "function_name/arity" do
    test "when ..." do
    end
  end

  # private helpers at the bottom
  defp some_helper, do: ...
end
```

- `async: true` by default; use `async: false` only when tests share state (ETS, supervision, application env)
- Always include `doctest` for the module under test
- Import `Mox`, `Support.Config`, `ExUnit.CaptureLog` only when needed
- `setup :verify_on_exit!` and `setup :support_config` when using Mox

### Describe blocks

- Group by function: `describe "encode/2" do`
- Always include arity: `"resolve/1"`, not `"resolve"`
- For macros use the macro name: `describe "__using__/1" do`

### Test descriptions

- Always start with `"when ..."` describing the condition
- Lowercase, present tense, no trailing period
- Describe the scenario, not the expected outcome
- Good: `"when registry is not configured it uses local schema file"`
- Good: `"when payload was encoded with schema registry magic byte"`
- Good: `"when key is new"`
- Bad: `"should return error"`, `"returns {:ok, schema}"`, `"test encoding"`

### Assertions

- Pattern match success: `{:ok, decoded} = Encoder.decode(message)`
- Assert error inline: `assert Encoder.decode(bad) == {:error, :schema_required}`
- Check struct fields individually after extraction:
  ```elixir
  {:ok, schema} = Resolver.resolve(1)
  assert schema.id == 1
  assert is_nil(schema.version)
  assert schema.full_name == "io.acme.Payment"
  ```
- Use `is_nil/1` for nil checks: `assert is_nil(schema.id)`
- Use `refute` for negation: `refute Config.registry_schemas_autoreg()`
- Use `=~` for partial string matching: `assert output =~ "schema version is not supported"`

### Mocking with Mox

- Chain expectations on the same mock with `|>`:
  ```elixir
  Avrora.Storage.MemoryMock
  |> expect(:get, fn key ->
    assert key == "io.acme.Payment"

    {:ok, nil}
  end)
  |> expect(:put, fn key, value ->
    assert key == "io.acme.Payment"
    assert value == expected_schema

    {:ok, value}
  end)
  ```
- Assert arguments inside mock callbacks with `assert`
- Blank line between argument assertions and return value
- Use `stub/3` for config overrides: `stub(Avrora.ConfigMock, :registry_url, fn -> nil end)`
- Use `stub_with/2` for bulk defaults (done via `setup :support_config`)

### Log capturing

```elixir
output =
  capture_log(fn ->
    {:ok, decoded} = Encoder.decode(message, schema_name: "io.acme.Payment:42")

    assert decoded == expected
  end)

assert output =~ "with schema version is not supported"
```

- Run the operation and assert its result inside `capture_log`
- Assert log content outside with `=~`

### Test data

- Define as private functions at the bottom of the test module
- Name descriptively: `payment_schema_with_id`, `payment_json_schema`, `messenger_plain_message`
- Build schemas via `Schema.Encoder.from_json/1` then override fields:
  ```elixir
  defp payment_schema do
    {:ok, schema} = Schema.Encoder.from_json(payment_json_schema())
    %{schema | id: nil, version: nil}
  end
  ```
- Binary payloads as literals: `defp payment_message, do: <<0, 0, 0, 0, 42, ...>>`
- Map payloads as simple functions: `defp payment_payload, do: %{"id" => "...", "amount" => 15.99}`
- Wrap module calls with short helpers when passing context:
  ```elixir
  defp get(pid, key), do: Memory.get(pid, key)
  defp put(pid, key, value), do: Memory.put(pid, key, value)
  ```

### Integration tests

- Use `start_supervised/1` in setup, not manual start/stop
- Pass context via setup return: `%{memory: pid}`
- Destructure in test: `test "when key is new", %{memory: pid} do`

### Mix task tests

- Capture exit codes: `assert {:shutdown, 1} == catch_exit(Task.run([]))`
- Assert shell output: `assert_received {:mix_shell, :info, [output]}`
