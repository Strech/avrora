<p align="center">
    <img id="avroraLogo" width=200 src="/assets/logo.png"/>
    <h1 align="center">Avrora</h1>
</p>

<span class="nodoc">

[![Hex pm](https://img.shields.io/hexpm/v/avrora.svg?style=for-the-badge)](https://hex.pm/packages/avrora)
[![Hex Docs](https://img.shields.io/badge/api-docs-blue.svg?style=for-the-badge)](https://hexdocs.pm/avrora)
[![Build Status](https://img.shields.io/travis/Strech/avrora/master?style=for-the-badge)](https://travis-ci.org/Strech/avrora)

</span>

# Getting Started

This Elixir library supports convenient encoding and decoding of [Avro](https://avro.apache.org/) messages.

It can read the Avro schema from local files or the [Confluent® Schema Registry](https://www.confluent.io/confluent-schema-registry),
caching data in memory for performance.
It supports reading and writing data Kafka [wire format](https://docs.confluent.io/current/schema-registry/serializer-formatter.html#wire-format)
prefix and from [Object Container Files](https://avro.apache.org/docs/1.8.1/spec.html#Object+Container+Files)
formats. And has [Inter-Schema references](https://github.com/Strech/avrora/wiki/Inter-Schema-references) feature.

Many thanks to the [AvroTurf](https://github.com/dasch/avro_turf) Ruby gem for the inspiration.

## Add Avrora to your project

Add Avrora to `mix.exs` as a dependency:

```elixir
def deps do
  [
    {:avrora, "~> 0.13"}
  ]
end
```

## Configuration

Configure the library in `config/config.exs`:

```elixir
config :avrora,
  registry_url: "http://localhost:8081",
  registry_auth: {:basic, ["username", "password"]}, # optional
  registry_schemas_autoreg: false, # optional: if you want manually register schemas
  schemas_path: Path.expand("./priv/schemas"),
  names_cache_ttl: :timer.minutes(5) # optional: if you want periodic disk reads
```

- `registry_url` - URL for the Schema Registry, default `nil`
- `registry_auth` – Credentials to authenticate in the Schema Registry, default `nil`
- `registry_schemas_autoreg` - Flag for automatic schemas registration in the Schema Registry, default `true`
  (since [v0.13](https://github.com/Strech/avrora/releases/tag/v0.13.0))
- `schemas_path` - Base path for locally stored schema files, default `./priv/schemas`
- `names_cache_ttl` - Time in ms to cache schemas by name in memory, default
  `:infinity` (since [v0.10](https://github.com/Strech/avrora/releases/tag/v0.10.0))

Set `names_cache_ttl` to `:infinity` will cache forever (no more disk reads will
happen). This is safe when schemas are resolved in the Schema Registry by
numeric id or **versioned** name, as it is unique. If you need to reload schema
from the disk periodically, TTL different from `:infinity` ensures that.

If the schema is resolved by name it will be always overwritten with the latest
schema received from Schema Registry (this is a new behavior since [v0.10](https://github.com/Strech/avrora/releases/tag/v0.10.0)).

:bulb: Disable automatic schemas registration if you want to avoid storing schemas
and manually control registration process.

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
- `:ocf` - Use [Object Container File](https://avro.apache.org/docs/1.8.1/spec.html#Object+Container+Files)
  format, embedding the full schema with the data
- `:registry` - Write data with Confluent Schema Registry
  [Wire Format](https://docs.confluent.io/current/schema-registry/serializer-formatter.html#wire-format),
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
It first tries resolving the schema using the integer id in the
[wire format](https://docs.confluent.io/current/schema-registry/serializer-formatter.html#wire-format)
header.

Next it tries reading using the
[Object Container Files](https://avro.apache.org/docs/1.8.1/spec.html#Object+Container+Files)
embedded schema.

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
