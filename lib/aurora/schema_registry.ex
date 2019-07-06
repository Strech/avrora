defmodule Avrora.SchemaRegistry do
  @moduledoc """
  A small wrapper for [Confluent Schema Registry](https://docs.confluent.io/current/schema-registry/develop/api.html),
  with as less as possible functionality. Inspired by [Schemex](https://github.com/bencebalogh/schemex).
  """

  @doc """
  Fetch the latest version of the schema registered under a subject name.

  ## Examples

      Avrora.SchemaRegistry.latest("my.subject.name")
  """
  @spec latest(String.t()) :: {:ok, map()} | {:error, any()}
  def latest(subject), do: version(subject, "latest")

  @doc """
  Fetch a desired version of the schema registered under subject name.

  ## Examples

      Avrora.SchemaRegistry.version("my.subject.name", 1)
  """
  @spec version(String.t(), integer()) :: {:ok, map()} | {:error, any()}
  def version(subject, version),
    do: http_client().get("subjects/#{subject}/versions/#{version}")

  @doc """
  Fetch a schema by a globally unique numeric identifier.

  ## Examples

      Avrora.SchemaRegistry.schema(1)
  """
  @spec schema(String.t()) :: {:ok, map()} | {:error, any()}
  def schema(id), do: http_client().get("schemas/ids/#{id}")

  @doc """
  Register a new version of a schema under the subject name.

  ## Examples

      Avrora.SchemaRegistry.register("my.subject.name", %{"type" => "string"})
  """
  @spec register(String.t(), map()) :: {:ok, map()} | {:error, any()}
  def register(subject, schema),
    do: http_client().post("subjects/#{subject}/versions", schema)

  defp http_client do
    Application.get_env(:avrora, :http_client)
  end
end
