defmodule Avrora.Config do
  @moduledoc """
  Configuration for Avrora.

  ## Options:

      * `schemas_path` path to local schema files, default `./priv/schemas`
      * `registry_url` URL for Schema Registry, default `nil`
      * `registry_auth` authentication settings for Schema Registry, default `nil`
      * `registry_schemas_autoreg` automatically register schemas in Schema Registry, default `true`
      * `convert_null_values` convert `:null` values in the decoded message into `nil`, default `true`
      * `names_cache_ttl` duration to cache global schema names millisecods, default `:infinity`
      * `decoder_options` - Decoder options
        * `record_type` - output type of decoding record, default `:map`
        * `map_type` - output type of decoding map, default `:proplist`

  ## Internal use interface:

      * `file_storage` module which handles files in `schemas_path`, default `Avrora.Storage.File`
      * `memory_storage` module which handles memory operations, default `Avrora.Storage.Memory`
      * `registry_storage` module which handles Schema Registry requests, default `Avrora.Storage.Registry`
      * `http_client` module which handles HTTP client requests to Schema Registry, default `Avrora.HTTPClient`
      * `ets_lib` module which creates ETS tables with call `Module.new/0`
  """

  defmodule DecoderOptions do
    @type t :: %__MODULE__{
            map_type: :proplist | :map,
            record_type: :proplist | :map
          }
    defstruct map_type: :proplist, record_type: :map
  end

  @callback schemas_path :: String.t()
  @callback registry_url :: String.t() | nil
  @callback registry_auth :: tuple() | nil
  @callback registry_schemas_autoreg :: boolean()
  @callback convert_null_values :: boolean()
  @callback decoder_options :: DecoderOptions.t()
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
  def registry_schemas_autoreg, do: get_env(:registry_schemas_autoreg, true)

  @doc false
  def convert_null_values, do: get_env(:convert_null_values, true)

  @doc false
  def decoder_options,
    do: struct(DecoderOptions, get_env(:decoder_options, []))

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
