defmodule Avrora.ClientTest do
  use ExUnit.Case, async: true
  doctest Avrora.Client

  alias Fixtures.{Alpha, Beta}
  alias Fixtures.Alpha.Storage.Memory, as: AlphaMemory
  alias Fixtures.Beta.Storage.Memory, as: BetaMemory

  import Support.Config
  setup :support_config

  setup do
    start_supervised(Alpha)
    start_supervised(Beta)

    :ok
  end

  describe "__using__/1" do
    test "when encode and decode payload" do
      {:ok, alpha} = Alpha.encode(%{"id" => "Hello"}, schema_name: "io.Ping", format: :plain)
      {:ok, beta} = Beta.encode(%{"id" => "Hello"}, schema_name: "io.Pong", format: :plain)

      assert {:ok, %{"id" => "Hello"}} == Alpha.decode(alpha, schema_name: "io.Ping")
      assert {:ok, %{"id" => "Hello"}} == Beta.decode(beta, schema_name: "io.Pong")
    end

    test "when reading schema file from another client schemas store" do
      assert {:error, :enoent} == Alpha.encode(%{"id" => "Hello"}, schema_name: "io.Pong")
      assert {:error, :enoent} == Beta.encode(%{"id" => "Hello"}, schema_name: "io.Ping")
    end

    test "when loading schema from another client memory store" do
      {:ok, _} = Alpha.encode(%{"id" => "Hello"}, schema_name: "io.Ping", format: :plain)
      {:ok, _} = Beta.encode(%{"id" => "Hello"}, schema_name: "io.Pong", format: :plain)

      assert {:ok, nil} == AlphaMemory.get("io.Pong")
      assert {:ok, nil} == BetaMemory.get("io.Ping")
    end
  end

  @config_methods [
    :registry_url,
    :registry_auth,
    :registry_schemas_autoreg,
    :convert_null_values,
    :convert_map_to_proplist,
    :names_cache_ttl
  ]
  for method <- @config_methods do
    @tag method: method
    describe "#{method}/0" do
      test "when config is set", %{method: method} do
        refute apply(Fixtures.RuntimeConfigTest.Config, method, []) == :config_value

        Application.put_env(:runtime_config_test, Fixtures.RuntimeConfigTest, [
          {method, :config_value}
        ])

        assert apply(Fixtures.RuntimeConfigTest.Config, method, []) == :config_value
      end
    end
  end
end
