defmodule Avrora.Config do
  @moduledoc """
  Configuration for Avrora.

  ## Options:

      * `schemas_path` path to local schema files, default ./priv/schemas
      * `registry_url` URL for Confluent Schema Registry, default nil
      * `registry_auth` authentication settings for Confluent Schema Registry, default nil
      * `names_cache_ttl` duration to cache global schema names millisecods, default :infinity

  ## Module configuration:

      * `file_storage` module which handles files in `schemas_path`, default `Avrora.Storage.File`
      * `memory_storage` module which handles memory operations, default `Avrora.Storage.Memory`
      * `registry_storage` module which handles Schema Registry requests, default `Avrora.Storage.Registry`
      * `http_client` module which handles HTTP client requests to Schema Registry, default `Avrora.HTTPClient`
      * `ets_lib` module which creates ETS tables with call `Module.new/0`
  """

  @callback schemas_path :: String.t()
  @callback registry_url :: String.t() | nil
  @callback registry_auth :: tuple() | nil
  @callback names_cache_ttl :: integer() | atom()
  @callback file_storage :: module()
  @callback memory_storage :: module()
  @callback registry_storage :: module()
  @callback http_client :: module()
  @callback ets_lib :: module() | atom()

  @doc false
  def schemas_path, do: get_env(:schemas_path, Path.expand("./priv/schemas"))

  @doc false
  def registry_url, do: get_env(:registry_url, nil)

  @doc false
  def registry_auth, do: get_env(:registry_auth, nil)

  @doc false
  def names_cache_ttl, do: get_env(:names_cache_ttl, :infinity)

  @doc false
  def file_storage, do: Avrora.Storage.File

  @doc false
  def memory_storage, do: Avrora.Storage.Memory

  @doc false
  def registry_storage, do: Avrora.Storage.Registry

  @doc false
  def http_client, do: Avrora.HTTPClient

  @doc false
  def ets_lib, do: Avrora.AvroSchemaStore

  @doc false
  def self, do: get_env(:config, Avrora.Config)

  defp get_env(name, default), do: Application.get_env(:avrora, name, default)
end
