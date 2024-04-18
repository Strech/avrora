<p align="center" class="gfm">
    <img id="avroraLogo" width=200 src="/assets/logo.png"/>
    <h1 align="center">Avrora</h1>
</p>

<span class="nodoc">

[![Hex pm](https://img.shields.io/hexpm/v/avrora.svg?style=for-the-badge)](https://hex.pm/packages/avrora)
[![Hex Docs](https://img.shields.io/badge/api-docs-blue.svg?style=for-the-badge)](https://hexdocs.pm/avrora)

</span>

[v0.10]: https://github.com/Strech/avrora/releases/tag/v0.10.0
[v0.12]: https://github.com/Strech/avrora/releases/tag/v0.12.0
[v0.13]: https://github.com/Strech/avrora/releases/tag/v0.13.0
[v0.14]: https://github.com/Strech/avrora/releases/tag/v0.14.0
[v0.15]: https://github.com/Strech/avrora/releases/tag/v0.15.0
[v0.16]: https://github.com/Strech/avrora/releases/tag/v0.16.0
[v0.17]: https://github.com/Strech/avrora/releases/tag/v0.17.0
[v0.18]: https://github.com/Strech/avrora/releases/tag/v0.18.0
[v0.22]: https://github.com/Strech/avrora/releases/tag/v0.22.0
[v0.23]: https://github.com/Strech/avrora/releases/tag/v0.23.0
[v0.24]: https://github.com/Strech/avrora/releases/tag/v0.24.0
[v0.25]: https://github.com/Strech/avrora/releases/tag/v0.25.0
[v0.26]: https://github.com/Strech/avrora/releases/tag/v0.26.0
[v0.28]: https://github.com/Strech/avrora/releases/tag/v0.28.0
[1]: https://avro.apache.org/
[2]: https://www.confluent.io/confluent-schema-registry
[3]: https://docs.confluent.io/current/schema-registry/serializer-formatter.html#wire-format
[4]: https://avro.apache.org/docs/1.8.1/spec.html#Object+Container+Files
[5]: https://docs.confluent.io/current/schema-registry/serdes-develop/index.html#referenced-schemas
[6]: https://github.com/Strech/avrora/wiki/Inter-Schema-references
[7]: https://github.com/dasch/avro_turf
[8]: https://www.confluent.io/blog/multiple-event-types-in-the-same-kafka-topic/#avro-unions-with-schema-references
[9]: https://github.com/Strech/avrora/wiki/Schema-name-resolution
[10]: https://github.com/Strech/avrora/pull/70
[11]: https://github.com/klarna/erlavro#decoder-hooks
[12]: https://www.erlang.org/docs/26/man/ssl#type-client_cacerts

# Getting Started

This Elixir library supports convenient encoding and decoding of [Avro][1] messages.

It can read the Avro schema from local files or the [Confluent® Schema Registry][2],
caching data in memory for performance.

It supports reading and writing data Kafka [wire format][3] prefix and from [Object Container Files][4]
formats. Along with [Confluent® Schema References][5] it has [Inter-Schema references][6] feature for
older Schema Registry versions.

Many thanks to the [AvroTurf][7] Ruby gem for the initial inspiration :blue_heart:

---

#### If you like the project and want to support me on my sleepless nights, you can

[![Support via PayPal](https://cdn.rawgit.com/twolfson/paypal-github-button/1.0.0/dist/button.svg)](https://www.paypal.com/paypalme/onistrech/eur5.0)
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/W7W8367XJ)

## Add Avrora to your project

Add Avrora to `mix.exs` as a dependency

```elixir
def deps do
  [
    {:avrora, "~> 0.27"}
  ]
end
```

## Configuration

:beginner: It's recommended to configure private Avrora client<sup>[v0.17]</sup> to avoid
risk of conflicts with other dependencies which might use shared `Avrora` client.

Don't worry if you already using the shared client because migration to the private is a
matter of copy-paste.

### Private client

Create your private Avrora client module

```elixir
defmodule MyClient do
  use Avrora.Client,
    otp_app: :my_application,
    schemas_path: "./priv/schemas",
    registry_url: "http://localhost:8081",
    registry_auth: {:basic, ["username", "password"]},
    registry_user_agent: "Avrora/0.25.0 Elixir",
    registry_ssl_cacerts: File.read!("./priv/trusted.der"),
    registry_ssl_cacert_path: "./priv/trusted.crt",
    registry_schemas_autoreg: false,
    convert_null_values: false,
    convert_map_to_proplist: false,
    names_cache_ttl: :timer.minutes(5),
    decoder_hook: &MyClient.decoder_hook/4
end
```

please check the section below :point_down: for detailed explanation of each configuration option.

### Shared client

Configure the `Avrora` shared client in `config/config.exs`

```elixir
config :avrora,
  otp_app: :my_application, # optional, if you want to use it as a root folder for `schemas_path`
  schemas_path: "./priv/schemas",
  registry_url: "http://localhost:8081",
  registry_auth: {:basic, ["username", "password"]}, # optional
  registry_user_agent: "Avrora/0.24.2 Elixir", # optional: if you want to return previous behaviour, set it to `nil`
  registry_ssl_cacerts: File.read!("./priv/trusted.der"), # optional: if you have DER-encoded certificate
  registry_ssl_cacert_path: "./priv/trusted.crt", # optional: if you have PEM-encoded certificate file
  registry_schemas_autoreg: false, # optional: if you want manually register schemas
  convert_null_values: false, # optional: if you want to keep decoded `:null` values as is
  convert_map_to_proplist: false, # optional: if you want to restore the old behavior for decoding map-type
  names_cache_ttl: :timer.minutes(5), # optional: if you want periodic disk reads
  decoder_hook: &MyClient.decoder_hook/4 # optional: if you want to amend the data/result
```

- `otp_app`<sup>[v0.22]</sup> - Name of the OTP application to use for runtime configuration via env, default `nil`
- `schemas_path` - Base path for locally stored schema files, default `./priv/schemas`
- `registry_url` - URL for the Schema Registry, default `nil`
- `registry_auth` – Credentials to authenticate in the Schema Registry, default `nil`
- `registry_user_agent`<sup>[v0.25]</sup> - HTTP `User-Agent` header for Schema Registry requests, default `Avrora/<version> Elixir`
- `registry_ssl_cacerts`<sup>[v0.28]</sup> - DER-encoded certificates, but [without combined support][12], default `nil`
- `registry_ssl_cacert_path`<sup>[v0.28]</sup> - Path to a file containing PEM-encoded CA certificates, default `nil`
- `registry_schemas_autoreg`<sup>[v0.13]</sup> - Flag for automatic schemas registration in the Schema Registry, default `true`
- `convert_null_values`<sup>[v0.14]</sup> - Flag for automatic conversion of decoded `:null` values into `nil`, default `true`
- `convert_map_to_proplist`<sup>[v0.15]</sup> restore old behaviour and confiugre decoding map-type to proplist, default `false`
- `names_cache_ttl`<sup>[v0.10]</sup> - Time in ms to cache schemas by name in memory, default `:infinity`
- `decoder_hook`<sup>[v0.24]</sup> - Function with arity 4 to amend data or result, default `fn _, _, data, fun -> fun.(data) end`

Set `names_cache_ttl` to `:infinity` will cache forever (no more disk reads will
happen). This is safe when schemas resolved in the Schema Registry by
numeric id or **versioned** name, as it is unique. If you need to reload schema
from the disk periodically, TTL different from `:infinity` ensures that.

If the schema resolved by name it will be always overwritten with the latest
schema received from Schema Registry.<sup>[v0.10]</sup>

Custom [decoder hook][11] will be first in the call-chain, after it's done Avrora
will use the result in its own decoder hook.<sup>[v0.24]</sup>

:bulb: Disable schemas auto-registration if you want to avoid storing schemas
and manually control registration process. Also it's recommended to turn off auto-registration
when schemas containing [Confluent Schema References][8].<sup>[v0.14]</sup>

:bulb: When you use releases and especially Umbrella apps with different clients it's
recommended to set `otp_app` which will point to your OTP applications. This will allow you
to have a per-client runtime resolution for all configuration options (i.e. `schemas_path`)
with a fallback to staticly defined in a client itself.<sup>[v0.23]</sup>

:bulb: If both `registry_ssl_cacerts` and `registry_ssl_cacert_path` given, then
`registry_ssl_cacerts` has a priority.

## Start cache process

Avrora uses an in-memory cache to speed up schema lookup.

### Private client

After you've created your [private Avrora client](#private-client),
add it to your supervision tree

```elixir
children = [
  MyClient
]

Supervisor.start_link(children, strategy: :one_for_one)
```

or start the process manually

```elixir
{:ok, pid} = MyClient.start_link()
```

### Shared client

Add shared `Avrora` module to your supervision tree

```elixir
children = [
  Avrora
]

Supervisor.start_link(children, strategy: :one_for_one)
```

or start the process manually

```elixir
{:ok, pid} = Avrora.start_link()
```

## Usage

:beginner: All the examples below (including [Schemas registration](#schemas-registration))
will use `Avrora` shared client, but if you are using private client,
just replace `Avrora` with your client module name.

The primary way to use the library is via the `Avrora.encode/2` and
`Avrora.decode/2` functions. These functions load the Avro schema for you.

If `registry_url` defined, it enables Schema Registry storage. If the schema
file found locally but not in the registry, either fuction will register the schema.

These examples assume you have a `Payment` schema stored in the file
`priv/schemas/io/confluent/Payment.avsc`

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

When running interactively, first make sure the cache started

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

- `:plain`<sup>deprecated [v0.18]</sup> - Just return Avro binary data, with no header or embedded schema
- `:ocf` - Use [Object Container File][4]
  format, embedding the full schema with the data
- `:registry` - Write data with Confluent Schema Registry
  [Wire Format][3],
  which prefixes the data with the schema id
- `:guess` - Use `:registry` if possible, otherwise use `:ocf` (default)

```elixir
{:ok, pid} = Avrora.start_link()
message = %{"id" => "tx-1", "amount" => 15.99}

{:ok, encoded} = Avrora.encode(message, schema_name: "io.confluent.Payment", format: :registry)
<<0, 0, 42, 0, 8, 116, 120, 45, 49, 123, 20, 174, 71, 225, 250, 47, 64>>
```

### decode/2

Decode `Payment` message using the specified schema

```elixir
{:ok, pid} = Avrora.start_link()
message = <<0, 0, 42, 0, 8, 116, 120, 45, 49, 123, 20, 174, 71, 225, 250, 47, 64>>

{:ok, decoded} = Avrora.decode(message, schema_name: "io.confluent.Payment")
%{"id" => "tx-1", "amount" => 15.99}
```

### decode/1

Decode a message, auto-detecting the schema using magic bytes.
It first tries resolving the schema using the integer id in the [wire format][3] header.

Next it tries reading using the [Object Container Files][4] embedded schema.

**NOTE:** Messages encoded with OCF wrapped in a List.

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

:bulb: Due to [possible collision][10] of the `:plain` format and `:registry` via magic-like
byte sequence it's recommended<sup>[v0.18]</sup> to use `Avrora.decode_plain/2` and `Avrora.encode_plain/2` if
you are working with `:plain` format (see in all available functions).

<details class="nodoc">
  <summary>:mag: Click to expand for all available functions</summary>

### decode_plain/2<sup>[0.18]</sup>

Decode a message encoded in a `:plain` format.

```elixir
{:ok, pid} = Avrora.start_link()
message = <<8, 116, 120, 45, 49, 123, 20, 174, 71, 225, 250, 47, 64>>

{:ok, decoded} = Avrora.decode(message, schema_name: "io.confluent.Payment")
%{"id" => "tx-1", "amount" => 15.99}
```

### encode_plain/2<sup>[0.18]</sup>

Encode a payload in a `:plain` format.

```elixir
{:ok, pid} = Avrora.start_link()
message = %{"id" => "tx-1", "amount" => 15.99}

{:ok, encoded} = Avrora.encode(message, schema_name: "io.confluent.Payment")
<<8, 116, 120, 45, 49, 123, 20, 174, 71, 225, 250, 47, 64>>
```

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

## Schemas registration

There are two ways you can register AVRO schemas if you have disabled auto-registration.

If you want to make it a part of your code, but with better control, you can use
`Avrora.Utils.Registrar` module and if you want to embed it in the deployment use
a mix task `avrora.reg.schema`.

### Avrora.Utils.Registrar<sup>[v0.16]</sup>

This module is cache-aware and thus it can be used inside intensive loops if needed.
It provides two ways to register schema:

- by name, then it will be resolved to a file with [library conventions][9]
- by schema, then a given schema will be used without any disk reads

But keep in mind that either way has a memory check to ensure that schema was not
registered before and to bypass this check you have to use `force: true` flag

```elixir
{:ok, schema} = Avrora.Utils.Registrar.register_schema_by_name("io.confluent.Payment", force: true)
```

In addition, any schema can be registered under different subject via `as: "NewName"` option

```elixir
{:ok, schema} = Avrora.Storage.File.get("io.confluent.Payment")
{:ok, schema_with_id} = Avrora.Utils.Registrar.register_schema(schema, as: "NewName")
```

### mix avrora.reg.schema<sup>[v0.12]</sup>

A separate mix task to register a specific schema or all found schemas in
schemas folder (see [configuration](#configuration) section).

For instance, if you configure Avrora schemas folder to be at `./priv/schemas`
and you want to register a schema `io/confluent/Payment.avsc` then you can use
this command

```console
$ mix avrora.reg.schema --name io.confluent.Payment
schema `io.confluent.Payment' will be registered
```

In addition, any schema can be registered under different subject via `--as` option<sup>[v0.16]</sup>

```console
$ mix avrora.reg.schema --name io.confluent.Payment --as MyCustomName
schema `io.confluent.Payment' will be registered as `MyCustomName'
```

If you would like to register all schemas found under `./priv/schemas` then you
can simply execute this command

```console
$ mix avrora.reg.schema --all
schema `io.confluent.Payment' will be registered
schema `io.confluent.Wrong' will be skipped due to an error `argument error'
```

Additional application config to load additional can be set via `--appconfig` option<sup>[v0.26]</sup>

```console
$ mix avrora.reg.schema --name io.confluent.Payment --appconfig runtime
schema `io.confluent.Payment' will be registered
```
