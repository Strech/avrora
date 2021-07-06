defmodule Avrora.ClientTest do
  use ExUnit.Case, async: false
  doctest Avrora.Client

  alias Fixtures.{Alpha, Beta, Gamma}
  alias Fixtures.Alpha.Storage.Memory, as: AlphaMemory
  alias Fixtures.Beta.Storage.Memory, as: BetaMemory

  import Support.Config
  setup :support_config

  setup do
    start_supervised(Alpha)
    start_supervised(Beta)
    start_supervised(Gamma)

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

    test "when otp_app is set" do
      Application.put_env(:area, Gamma, schemas_path: "./path/to/schemas")
      Code.prepend_path("test/fixtures/area-52/ebin")

      assert Gamma.Config.names_cache_ttl() == 1_000
      assert Gamma.Config.schemas_path() =~ "avrora/test/fixtures/area-52/./path/to/schemas"

      Application.put_env(:area, Gamma, schemas_path: "./my/scms", names_cache_ttl: 42)

      assert Gamma.Config.names_cache_ttl() == 42
      assert Gamma.Config.schemas_path() =~ "avrora/test/fixtures/area-52/./my/scms"
    end

    test "when otp_app is not set" do
      assert Beta.Config.names_cache_ttl() == :infinity

      Application.put_env(:area, Beta, names_cache_ttl: 42)

      assert Beta.Config.names_cache_ttl() == :infinity
    end
  end
end
