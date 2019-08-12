<p align="center">
    <img id="avroraLogo" width=200 src="/assets/logo.png"/>
    <h1 align="center">Avrora</h1>
</p>

<span id="badges">

[![Hex pm](https://img.shields.io/hexpm/v/avrora.svg?style=flat)](https://hex.pm/packages/avrora)
[![Hex Docs](https://img.shields.io/badge/api-docs-blue.svg?style=flat)](https://hexdocs.pm/avrora)
[![Build Status](https://travis-ci.org/Strech/avrora.svg?branch=master)](https://travis-ci.org/Strech/avrora)

</span>

# Getting Started

An Elixir library for convenient work with Avro messages.
It supports local schema files and Confluent® schema registry.

Many thanks to [AvroTurf](https://github.com/dasch/avro_turf) Ruby gem for an inspiration.

## Add Avrora to your project

To use Avrora with your projects, edit your `mix.exs` file and add it as a dependency

```elixir
def deps do
  [
    {:avrora, "~> 0.2"}
  ]
end
```

## Configure

The main configuration options is confluent schema registry url and path to
locally stored schemas. Add it in your `config/confix.exs`

```elixir
config :avrora,
  registry_url: "http://localhost:8081",      # default to `nil`
  schemas_path: Path.expand("./priv/schemas") # default to `./priv/schemas`
```

If you will set `registry_url` to a non-`nil` value, then each time we need to find
out what schema did you mean (except known and cached) it will be first fetched from the
schema registry and in case if it's not found we will do lookup in the local schemas.

In addition schemas which was not found in the registry
will be registered on encoding/decoding time.

## Start new process manually

Avrora is using in-memory cache to speed up known schemas lookup

```elixir
{:ok, pid} = Avrora.start_link()
```

## Use in supervision tree

Avrora supports child specs, so you can use it as part of a supervision tree

```elixir
children = [
  Avrora
]

Supervisor.start_link(children, strategy: :one_for_one)
```

## Basic Usage

Let's say you have this `Payment` schema stored in a file `priv/schemas/io/confluent/Payment.avsc`

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

### encode/2

To encode payment message with `Payment.avsc` schema

```elixir
message = %{"id" => "tx-1", "amount" => 15.99}

{:ok, pid} = Avrora.start_link()
{:ok, encoded} = Avrora.encode(message, schema_name: "io.confluent.Payment")
<<8, 116, 120, 45, 49, 123, 20, 174, 71, 225, 250, 47, 64>>
```

### decode/2

To decode payment message with `Payment.avsc` schema

```elixir
message = <<8, 116, 120, 45, 49, 123, 20, 174, 71, 225, 250, 47, 64>>

{:ok, pid} = Avrora.start_link()
{:ok, decoded} = Avrora.decode(message, schema_name: "io.confluent.Payment")
%{"id" => "tx-1", "amount" => 15.99}
```

### decode/1

Schema-agnostic method of decoding messages, doesn't require to provide a schema
name. Instead it relies on artifacts in a message about which schema to use.

It works for messages encoded with [Schema Registry magic bytes](https://docs.confluent.io/current/schema-registry/serializer-formatter.html#wire-format)
and [Object Container Files bytes](https://avro.apache.org/docs/1.8.1/spec.html#Object+Container+Files).
In case of Schema Registry it will try to fetch schema from the registry and
in case of OCF it will usee embeded schema in the message.

**NOTE:** When message encoded with OCF it should be always wrapped in a List.

```elixir
message = <<79, 98, 106, 1, 3, 204, 2, 20, 97, 118, 114, 111, 46, 99, 111, 100, 101, 99, 8, 110, 117, 108, 108, 22, 97, 118, 114, 111, 46, 115, 99, 104, 101, 109, 97, 144, 2, 123, 34, 110, 97, 109, 101, 115, 112, 97, 99, 101, 34, 58, 34, 105, 111, 46, 99, 111, 110, 102, 108, 117, 101, 110, 116, 34, 44, 34, 110, 97, 109, 101, 34, 58, 34, 80, 97, 121, 109, 101, 110, 116, 34, 44, 34, 116, 121, 112, 101, 34, 58, 34, 114, 101, 99, 111, 114, 100, 34, 44, 34, 102, 105, 101, 108, 100, 115, 34, 58, 91, 123, 34, 110, 97, 109, 101, 34, 58, 34, 105, 100, 34, 44, 34, 116, 121, 112, 101, 34, 58, 34, 115, 116, 114, 105, 110, 103, 34, 125, 44, 123, 34, 110, 97, 109, 101, 34, 58, 34, 97, 109, 111, 117, 110, 116, 34, 44, 34, 116, 121, 112, 101, 34, 58, 34, 100, 111, 117, 98, 108, 101, 34, 125, 93, 125, 0, 84, 229, 97, 195, 95, 74, 85, 204, 143, 132, 4, 241, 94, 197, 178, 106, 2, 26, 8, 116, 120, 45, 49, 123, 20, 174, 71, 225, 250, 47, 64, 84, 229, 97, 195, 95, 74, 85, 204, 143, 132, 4, 241, 94, 197, 178, 106>>

{:ok, pid} = Avrora.start_link()
{:ok, decoded} = Avrora.decode(message)
[%{"id" => "tx-1", "amount" => 15.99}]
```

## Roadmap

- [x] Debug logging
- [x] [Avro OCF](https://avro.apache.org/docs/1.8.1/spec.html#Object+Container+Files) decoding
- [ ] [Avro OCF](https://avro.apache.org/docs/1.8.1/spec.html#Object+Container+Files) encoding
- [ ] Add `format: bare|csr|ocf|auto` to `Avrora.encode/2` method
