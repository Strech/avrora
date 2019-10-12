defmodule Avrora.Config do
  @moduledoc """
  Configuration for Avrora.

  ## Options:

      * `schemas_path` path to local schema files, default ./priv/schemas
      * `registry_url` URL for Confluent Schema Registry, default nil
      * `names_cache_ttl` duration to cache global schema names millisecods, default 300_000

  ## Module configuration:

      * `file_storage` module which handles files in `schemas_path`, default `Avrora.Storage.File`
      * `memory_storage` module which handles memory operations, default `Avrora.Storage.Memory`
      * `registry_storage` module which handles Schema Registry requests, default `Avrora.Storage.Registry`
      * `http_client` module which handles HTTP client requests to Schema Registry, default `Avrora.HTTPClient`
  """

  @doc false
  def schemas_path, do: get_env(:schemas_path, Path.expand("./priv/schemas"))

  @doc false
  def registry_url, do: get_env(:registry_url, nil)

  @doc false
  def names_cache_ttl, do: get_env(:names_cache_ttl, :timer.minutes(5))

  @doc false
  def file_storage, do: get_env(:file_storage, Avrora.Storage.File)

  @doc false
  def memory_storage, do: get_env(:memory_storage, Avrora.Storage.Memory)

  @doc false
  def registry_storage, do: get_env(:registry_storage, Avrora.Storage.Registry)

  @doc false
  def http_client, do: get_env(:http_client, Avrora.HTTPClient)

  defp get_env(name, default), do: Application.get_env(:avrora, name, default)
end
