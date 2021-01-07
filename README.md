<p align="center" class="gfm">
    <img id="avroraLogo" width=200 src="/assets/logo.png"/>
    <h1 align="center">Avrora</h1>
</p>

<span class="nodoc">

[![Hex pm](https://img.shields.io/hexpm/v/avrora.svg?style=for-the-badge)](https://hex.pm/packages/avrora)
[![Hex Docs](https://img.shields.io/badge/api-docs-blue.svg?style=for-the-badge)](https://hexdocs.pm/avrora)
[![Build Status](https://img.shields.io/github/workflow/status/Strech/Avrora/CI?style=for-the-badge)](https://github.com/Strech/avrora/actions?query=workflow%3ACI)

</span>

[v0.10]: https://github.com/Strech/avrora/releases/tag/v0.10.0
[v0.12]: https://github.com/Strech/avrora/releases/tag/v0.12.0
[v0.13]: https://github.com/Strech/avrora/releases/tag/v0.13.0
[v0.14]: https://github.com/Strech/avrora/releases/tag/v0.14.0
[v0.15]: https://github.com/Strech/avrora/releases/tag/v0.15.0
[1]: https://avro.apache.org/
[2]: https://www.confluent.io/confluent-schema-registry
[3]: https://docs.confluent.io/current/schema-registry/serializer-formatter.html#wire-format
[4]: https://avro.apache.org/docs/1.8.1/spec.html#Object+Container+Files
[5]: https://docs.confluent.io/current/schema-registry/serdes-develop/index.html#referenced-schemas
[6]: https://github.com/Strech/avrora/wiki/Inter-Schema-references
[7]: https://github.com/dasch/avro_turf
[8]: https://www.confluent.io/blog/multiple-event-types-in-the-same-kafka-topic/#avro-unions-with-schema-references

# Getting Started

This Elixir library supports convenient encoding and decoding of [Avro][1] messages.

It can read the Avro schema from local files or the [Confluent® Schema Registry][2],
caching data in memory for performance.

It supports reading and writing data Kafka [wire format][3] prefix and from [Object Container Files][4]
formats. Along with [Confluent® Schema References][5] it has [Inter-Schema references][6] feature for
older Schema Registry versions.

Many thanks to the [AvroTurf][7] Ruby gem for the inspiration.

## Add Avrora to your project

Add Avrora to `mix.exs` as a dependency:

```elixir
def deps do
  [
    {:avrora, "~> 0.14"}
  ]
end
```

## Configuration

Configure the library in `config/config.exs`:

```elixir
config :avrora,
  registry_url: "http://localhost:8081",
  registry_auth: {:basic, ["username", "password"]}, # optional
  schemas_path: Path.expand("./priv/schemas"),
  registry_schemas_autoreg: false, # optional: if you want manually register schemas
  convert_null_values: false, # optional: if you want to keep decoded `:null` values as is
  convert_map_to_proplist: false # optional: if you want to restore the old behavior for decoding map-type
  names_cache_ttl: :timer.minutes(5) # optional: if you want periodic disk reads
```

- `registry_url` - URL for the Schema Registry, default `nil`
- `registry_auth` – Credentials to authenticate in the Schema Registry, default `nil`
- `schemas_path` - Base path for locally stored schema files, default `./priv/schemas`
- `registry_schemas_autoreg`<sup>[v0.13]</sup> - Flag for automatic schemas registration in the Schema Registry, default `true`
- `convert_null_values`<sup>[v0.14]</sup> - Flag for automatic conversion of decoded `:null` values into `nil`, default `true`
- `convert_map_to_proplist`<sup>[v0.15]</sup> restore old behaviour and confiugre decoding map-type to proplist, default `false`
- `names_cache_ttl`<sup>[v0.10]</sup> - Time in ms to cache schemas by name in memory, default `:infinity`

Set `names_cache_ttl` to `:infinity` will cache forever (no more disk reads will
happen). This is safe when schemas are resolved in the Schema Registry by
numeric id or **versioned** name, as it is unique. If you need to reload schema
from the disk periodically, TTL different from `:infinity` ensures that.

If the schema is resolved by name it will be always overwritten with the latest
schema received from Schema Registry.<sup>[v0.10]</sup>

:bulb: Disable schemas auto-registration if you want to avoid storing schemas
and manually control registration process. Also it is recommended to turn off auto-registration
when schemas containing [Confluent Schema References][8].<sup>[v0.14]</sup>

## Start cache process

Avrora uses an in-memory cache to speed up schema lookup.

Add it to your supervision tree:

```elixir
children = [
  Avrora
]

Supervisor.start_link(children, strategy: :one_for_one)
```

Or start the cache process manually:

```elixir
{:ok, pid} = Avrora.start_link()
```

## Sponsorship

If you like the project and want to support me on my sleepless nights, you can

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/W7W8367XJ)

[![Support via PayPal](https://cdn.rawgit.com/twolfson/paypal-github-button/1.0.0/dist/button.svg)](https://www.paypal.com/paypalme/onistrech/eur5.0)

## Usage

The primary way to use the library is via the `Avrora.encode/2` and
`Avrora.decode/2` functions. These functions load the Avro schema for you.

If `registry_url` is defined, it enables Schema Registry storage. If the schema
file found locally but not in the registry, either fuction will register the schema.

These examples assume you have a `Payment` schema stored in the file
`priv/schemas/io/confluent/Payment.avsc`:

```json
{
  "type": "record",
  "name": "Payment",
  "namespace": "io.confluent",
  "fields": [
    {
      "name": "id",
      "type": "string"
    },
    {
      "name": "amount",
      "type": "double"
    }
  ]
}
```

When running interactively, first make sure the cache is started:

```elixir
{:ok, pid} = Avrora.start_link()
```

### encode/2

To encode a `Payment` message:

```elixir
{:ok, pid} = Avrora.start_link()
message = %{"id" => "tx-1", "amount" => 15.99}

{:ok, encoded} = Avrora.encode(message, schema_name: "io.confluent.Payment")
<<79, 98, 106, 1, 3, 204, 2, 20, 97, 118, 114, 111, 46, 99, 111, 100, 101, 99,
  8, 110, 117, 108, 108, 22, 97, 118, 114, 111, 46, 115, 99, 104, 101, 109, 97,
  144, 2, 123, 34, 110, 97, 109, 101, 115, 112, 97, 99, 101, 34, 58, 34, 105,
  111, 46, 99, 111, 110, 102, 108, 117, 101, 110, 116, 34, 44, 34, 110, 97, 109,
  101, 34, 58, 34, 80, 97, 121, 109, 101, 110, 116, 34, 44, 34, 116, 121, 112,
  101, 34, 58, 34, 114, 101, 99, 111, 114, 100, 34, 44, 34, 102, 105, 101, 108,
  100, 115, 34, 58, 91, 123, 34, 110, 97, 109, 101, 34, 58, 34, 105, 100, 34,
  44, 34, 116, 121, 112, 101, 34, 58, 34, 115, 116, 114, 105, 110, 103, 34, 125,
  44, 123, 34, 110, 97, 109, 101, 34, 58, 34, 97, 109, 111, 117, 110, 116, 34,
  44, 34, 116, 121, 112, 101, 34, 58, 34, 100, 111, 117, 98, 108, 101, 34, 125,
  93, 125, 0, 138, 124, 66, 49, 157, 51, 242, 3, 33, 52, 161, 147, 221, 174,
  114, 48, 2, 26, 8, 116, 120, 45, 49, 123, 20, 174, 71, 225, 250, 47, 64, 138,
  124, 66, 49, 157, 51, 242, 3, 33, 52, 161, 147, 221, 174, 114, 48>>
```

The `:format` argument controls output format:

- `:plain` - Just return Avro binary data, with no header or embedded schema
- `:ocf` - Use [Object Container File][4]
  format, embedding the full schema with the data
- `:registry` - Write data with Confluent Schema Registry
  [Wire Format][3],
  which prefixes the data with the schema id
- `:guess` - Use `:registry` if possible, otherwise use `:ocf` (default)

```elixir
{:ok, pid} = Avrora.start_link()
message = %{"id" => "tx-1", "amount" => 15.99}

{:ok, encoded} = Avrora.encode(message, schema_name: "io.confluent.Payment", format: :plain)
<<8, 116, 120, 45, 49, 123, 20, 174, 71, 225, 250, 47, 64>>
```

### decode/2

Decode `Payment` message using the specified schema:

```elixir
{:ok, pid} = Avrora.start_link()
message = <<8, 116, 120, 45, 49, 123, 20, 174, 71, 225, 250, 47, 64>>

{:ok, decoded} = Avrora.decode(message, schema_name: "io.confluent.Payment")
%{"id" => "tx-1", "amount" => 15.99}
```

### decode/1

Decode a message, auto-detecting the schema using magic bytes.
It first tries resolving the schema using the integer id in the [wire format][3] header.

Next it tries reading using the [Object Container Files][4] embedded schema.

**NOTE:** Messages encoded with OCF are wrapped in a List.

```elixir
{:ok, pid} = Avrora.start_link()
message =
  <<79, 98, 106, 1, 3, 204, 2, 20, 97, 118, 114, 111, 46, 99, 111, 100, 101, 99,
    8, 110, 117, 108, 108, 22, 97, 118, 114, 111, 46, 115, 99, 104, 101, 109, 97,
    144, 2, 123, 34, 110, 97, 109, 101, 115, 112, 97, 99, 101, 34, 58, 34, 105,
    111, 46, 99, 111, 110, 102, 108, 117, 101, 110, 116, 34, 44, 34, 110, 97, 109,
    101, 34, 58, 34, 80, 97, 121, 109, 101, 110, 116, 34, 44, 34, 116, 121, 112,
    101, 34, 58, 34, 114, 101, 99, 111, 114, 100, 34, 44, 34, 102, 105, 101, 108,
    100, 115, 34, 58, 91, 123, 34, 110, 97, 109, 101, 34, 58, 34, 105, 100, 34, 44,
    34, 116, 121, 112, 101, 34, 58, 34, 115, 116, 114, 105, 110, 103, 34, 125, 44,
    123, 34, 110, 97, 109, 101, 34, 58, 34, 97, 109, 111, 117, 110, 116, 34, 44,
    34, 116, 121, 112, 101, 34, 58, 34, 100, 111, 117, 98, 108, 101, 34, 125, 93,
    125, 0, 84, 229, 97, 195, 95, 74, 85, 204, 143, 132, 4, 241, 94, 197, 178, 106,
    2, 26, 8, 116, 120, 45, 49, 123, 20, 174, 71, 225, 250, 47, 64, 84, 229, 97,
    195, 95, 74, 85, 204, 143, 132, 4, 241, 94, 197, 178, 106>>

{:ok, decoded} = Avrora.decode(message)
[%{"id" => "tx-1", "amount" => 15.99}]
```

<details class="nodoc">
  <summary>:mag: Click to expand for all available functions</summary>

### extract_schema/1

Extracts a schema from the encoded message, useful when you would like to have
some metadata about the schema used to encode the message. All the retrieved schemas
will be cached accordingly to the settings.

```elixir
{:ok, pid} = Avrora.start_link()
message =
  <<79, 98, 106, 1, 3, 204, 2, 20, 97, 118, 114, 111, 46, 99, 111, 100, 101, 99,
    8, 110, 117, 108, 108, 22, 97, 118, 114, 111, 46, 115, 99, 104, 101, 109, 97,
    144, 2, 123, 34, 110, 97, 109, 101, 115, 112, 97, 99, 101, 34, 58, 34, 105,
    111, 46, 99, 111, 110, 102, 108, 117, 101, 110, 116, 34, 44, 34, 110, 97, 109,
    101, 34, 58, 34, 80, 97, 121, 109, 101, 110, 116, 34, 44, 34, 116, 121, 112,
    101, 34, 58, 34, 114, 101, 99, 111, 114, 100, 34, 44, 34, 102, 105, 101, 108,
    100, 115, 34, 58, 91, 123, 34, 110, 97, 109, 101, 34, 58, 34, 105, 100, 34, 44,
    34, 116, 121, 112, 101, 34, 58, 34, 115, 116, 114, 105, 110, 103, 34, 125, 44,
    123, 34, 110, 97, 109, 101, 34, 58, 34, 97, 109, 111, 117, 110, 116, 34, 44,
    34, 116, 121, 112, 101, 34, 58, 34, 100, 111, 117, 98, 108, 101, 34, 125, 93,
    125, 0, 84, 229, 97, 195, 95, 74, 85, 204, 143, 132, 4, 241, 94, 197, 178, 106,
    2, 26, 8, 116, 120, 45, 49, 123, 20, 174, 71, 225, 250, 47, 64, 84, 229, 97,
    195, 95, 74, 85, 204, 143, 132, 4, 241, 94, 197, 178, 106>>

{:ok, schema} = Avrora.extract_schema(message)
{:ok,
 %Avrora.Schema{
   full_name: "io.confluent.Payment",
   id: nil,
   json: "{\"namespace\":\"io.confluent\",\"name\":\"Payment\",\"type\":\"record\",\"fields\":[{\"name\":\"id\",\"type\":\"string\"},{\"name\":\"amount\",\"type\":\"double\"}]}",
   lookup_table: #Reference<0.146116641.3853647878.152744>,
   version: nil
 }}
```

</details>

## Mix tasks

A separate mix task to register a specific schema or all found schemas in
schemas folder (see [configuration](#configuration) section) is available
since [v0.12.0](https://github.com/Strech/avrora/releases/tag/v0.12.0).

For instance, if you configure Avrora schemas folder to be at `./priv/schemas`
and you want to register a schema `io/confluent/Payment.avsc` then you can use
this command

```console
$ mix avrora.reg.schema --name io.confluent.Payment
schema `io.confluent.Payment` will be registered
```

**NOTE:** It will search for schema `./priv/schemas/io/confluent/Payment.avsc`

If you would like to register all schemas found under `./priv/schemas` then you
can simply execute this command

```console
$ mix avrora.reg.schema --all
schema `io.confluent.Payment` will be registered
schema `io.confluent.Wrong' will be skipped due to an error `argument error'
```
