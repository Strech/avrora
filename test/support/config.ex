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

  def schemas_path, do: Path.expand("./test/fixtures/schemas")
  def registry_url, do: "http://reg.loc"
  def registry_auth, do: nil
  def names_cache_ttl, do: :infinity

  def file_storage, do: Avrora.Storage.FileMock
  def memory_storage, do: Avrora.Storage.MemoryMock
  def registry_storage, do: Avrora.Storage.RegistryMock
  def http_client, do: Avrora.HTTPClientMock
  def ets_lib, do: :avro_schema_store
end
