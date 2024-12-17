defmodule Support.Config do
  @moduledoc false
  @behaviour Avrora.Config

  @doc """
    A hook function to be used in `setup`-hook to enable a default configuration.
    Useful when `Avrora.Config` is used, but no or partial stubs are needed.

    ## Examples:

        defmodule MyTest do
          use ExUnit.Case, async: true

          alias Avrora.{Config, ConfigMock}

          import Mox
          import Support.Config
          setup :support_config

          test "uses default value" do
            asset Config.self().registry_url() == "http://reg.loc"
          end

          test "uses stubbed value or expectation" do
            stub(ConfigMock, :registry_url, fn -> nil end)

            asset is_nil(Config.self().registry_url())
          end
        end
  """
  def support_config(_context \\ %{}) do
    Mox.stub_with(Avrora.ConfigMock, __MODULE__)
    :ok
  end

  @impl true
  def schemas_path, do: Path.expand("./test/fixtures/schemas")
  @impl true
  def registry_url, do: "http://reg.loc"
  @impl true
  def registry_auth, do: nil
  @impl true
  def registry_user_agent, do: nil
  @impl true
  def registry_ssl_cacerts, do: nil
  @impl true
  def registry_ssl_cacert_path, do: nil
  @impl true
  def registry_ssl_opts, do: nil
  @impl true
  def registry_schemas_autoreg, do: true
  @impl true
  def convert_null_values, do: true
  @impl true
  def names_cache_ttl, do: :infinity
  @impl true
  def decoder_hook, do: fn _, _, data, fun -> fun.(data) end
  @impl true
  def convert_map_to_proplist, do: false
  @impl true
  def file_storage, do: Avrora.Storage.FileMock
  @impl true
  def memory_storage, do: Avrora.Storage.MemoryMock
  @impl true
  def registry_storage, do: Avrora.Storage.RegistryMock
  @impl true
  def http_client, do: Avrora.HTTPClientMock
  @impl true
  def ets_lib, do: :avro_schema_store
end
