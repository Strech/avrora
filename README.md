<p align="center">
  <img width=200 id="avroraLogo" src="/assets/logo.png"/>
  <h1 align="center">Avrora</h1>
</p>

[![Build Status](https://travis-ci.org/Strech/avrora.svg?branch=master)](https://travis-ci.org/Strech/avrora)

# Getting Started

Avrora is an Elixir library for convenient work with AVRO messages and schemas.
It was influenced by [AvroTurf](https://github.com/dasch/avro_turf) Ruby gem.

What is not implemented/working yet:

1. [Avro OCF](https://avro.apache.org/docs/1.8.1/spec.html#Object+Container+Files) encoding/decoding
2. Stable packag version
3. Debug logging

## Add Avrora to your project

To use Avrora with your projects, edit your `mix.exs` file and add it as a dependency

```elixir
def deps do
  [
    {:avrora, "~> 0.1.0"}
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
