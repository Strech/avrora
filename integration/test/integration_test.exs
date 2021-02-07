defmodule IntegrationTest do
  use ExUnit.Case, async: true

  alias Integration.Clients.{Alpha, Beta}
  alias Integration.Clients.Alpha.Storage.Memory, as: AlphaMemory
  alias Integration.Clients.Beta.Storage.Memory, as: BetaMemory

  setup_all do
    start_supervised(Alpha)
    start_supervised(Beta)

    :ok
  end

  describe "Alpha & Beta" do
    test "clients have encoding/decoding interface" do
      {:ok, alpha} = Alpha.encode(%{"id" => "Hello"}, schema_name: "io.Ping", format: :plain)
      {:ok, beta} = Beta.encode(%{"id" => "Hello"}, schema_name: "io.Pong", format: :plain)

      assert {:ok, %{"id" => "Hello"}} == Alpha.decode(alpha, schema_name: "io.Ping")
      assert {:ok, %{"id" => "Hello"}} == Beta.decode(beta, schema_name: "io.Pong")
    end

    test "client configurations are differs" do
      assert {:error, :enoent} == Alpha.encode(%{"id" => "Hello"}, schema_name: "Pong")
      assert {:error, :enoent} == Beta.encode(%{"id" => "Hello"}, schema_name: "Ping")
    end

    test "client memory storages are not shared" do
      {:ok, alpha} = Alpha.encode(%{"id" => "Hello"}, schema_name: "io.Ping", format: :plain)
      {:ok, beta} = Beta.encode(%{"id" => "Hello"}, schema_name: "io.Pong", format: :plain)

      assert {:ok, nil} == AlphaMemory.get("io.Pong")
      assert {:ok, nil} == BetaMemory.get("io.Ping")
    end
  end
end
