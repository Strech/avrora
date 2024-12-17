defmodule Avrora.Config do
  @moduledoc """
  Configuration for Avrora.

  ## Options:

      * `otp_app` name of the OTP application to use for addition `schemas_path` root folder configuration, default `nil`
      * `schemas_path` path to local schema files, default `./priv/schemas`
      * `registry_url` URL for Schema Registry, default `nil`
      * `registry_auth` authentication settings for Schema Registry, default `nil`
      * `registry_user_agent` HTTP `User-Agent` header for Schema Registry requests, default `Avrora/<version> Elixir`
      * `registry_ssl_cacerts` DER-encoded trusted certificate (not combined) (see https://www.erlang.org/docs/26/man/ssl#type-client_cacerts), default `nil`
      * `registry_ssl_cacert_path` path to a file containing PEM-encoded CA certificates, default `nil`
      * `registry_schemas_autoreg` automatically register schemas in Schema Registry, default `true`
      * `convert_null_values` convert `:null` values in the decoded message into `nil`, default `true`
      * `convert_map_to_proplist` bring back old behavior and configure decoding AVRO map-type as proplist, default `false`
      * `names_cache_ttl` duration to cache global schema names millisecods, default `:infinity`
      * `decoder_hook` function to amend decoded payload, default `fn _, _, data, fun -> fun.(data) end`

  ## Internal use interface:

      * `file_storage` module which handles files in `schemas_path`, default `Avrora.Storage.File`
      * `memory_storage` module which handles memory operations, default `Avrora.Storage.Memory`
      * `registry_storage` module which handles Schema Registry requests, default `Avrora.Storage.Registry`
      * `http_client` module which handles HTTP client requests to Schema Registry, default `Avrora.HTTPClient`
      * `ets_lib` module which creates ETS tables with call `Module.new/0`
  """

  @callback schemas_path :: String.t()
  @callback registry_url :: String.t() | nil
  @callback registry_auth :: tuple() | nil
  @callback registry_user_agent :: String.t() | nil
  @callback registry_ssl_cacerts :: binary() | nil
  @callback registry_ssl_cacert_path :: String.t() | nil
  @callback registry_ssl_opts :: [:ssl.tls_option()] | nil
  @callback registry_schemas_autoreg :: boolean()
  @callback convert_null_values :: boolean()
  @callback convert_map_to_proplist :: boolean()
  @callback names_cache_ttl :: integer() | atom()
  @callback decoder_hook :: (any(), any(), any(), any() -> any())
  @callback file_storage :: module()
  @callback memory_storage :: module()
  @callback registry_storage :: module()
  @callback http_client :: module()
  @callback ets_lib :: module() | atom()

  @doc false
  def schemas_path do
    path = get_env(:schemas_path, "./priv/schemas")
    otp_app = get_env(:otp_app, nil)

    if is_nil(otp_app), do: Path.expand(path), else: Application.app_dir(otp_app, path)
  end

  @doc false
  def registry_url, do: get_env(:registry_url, nil)

  @doc false
  def registry_auth, do: get_env(:registry_auth, nil)

  @doc false
  def registry_user_agent, do: get_env(:registry_user_agent, "Avrora/#{version()} Elixir")

  # NOTE: Starting OTP-25 it is possible to call `public_key:cacerts_get`
  #       See https://erlef.github.io/security-wg/secure_coding_and_deployment_hardening/ssl
  @doc false
  def registry_ssl_cacerts, do: get_env(:registry_ssl_cacerts, nil)

  @doc false
  def registry_ssl_cacert_path do
    path = get_env(:registry_ssl_cacert_path, nil)

    if is_nil(path), do: nil, else: Path.expand(path)
  end

  @doc false
  def registry_schemas_autoreg, do: get_env(:registry_schemas_autoreg, true)

  @doc false
  def convert_null_values, do: get_env(:convert_null_values, true)

  @doc false
  def convert_map_to_proplist, do: get_env(:convert_map_to_proplist, false)

  @doc false
  def names_cache_ttl, do: get_env(:names_cache_ttl, :infinity)

  @doc false
  def decoder_hook, do: get_env(:decoder_hook, fn _, _, data, fun -> fun.(data) end)

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
  defp version, do: Application.spec(:avrora, :vsn)
end
