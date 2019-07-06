defmodule Avrora.SchemaRegistryTest do
  use ExUnit.Case, async: true
  doctest Avrora.SchemaRegistry

  import Mox
  alias Avrora.SchemaRegistry

  setup :verify_on_exit!

  describe "latest/1" do
    test "when request was successful" do
      SchemaRegistry.HttpClientMock
      |> expect(:get, fn url ->
        assert url == "subjects/my.subject/versions/latest"

        {:ok, %{"id" => 1, "schema" => ~s({"hello":"world"})}}
      end)

      {status, response} = SchemaRegistry.latest("my.subject")

      assert status == :ok
      assert response == %{"id" => 1, "schema" => ~s({"hello":"world"})}
    end

    test "when request was unsuccessful" do
      SchemaRegistry.HttpClientMock
      |> expect(:get, fn url ->
        assert url == "subjects/my.subject/versions/latest"

        {:error, "Something went wrong!"}
      end)

      {status, response} = SchemaRegistry.latest("my.subject")

      assert status == :error
      assert response == "Something went wrong!"
    end
  end

  describe "version/2" do
    test "when request was successful" do
      SchemaRegistry.HttpClientMock
      |> expect(:get, fn url ->
        assert url == "subjects/my.subject/versions/42"

        {:ok, %{"id" => 42, "schema" => ~s({"hello":"world"})}}
      end)

      {status, response} = SchemaRegistry.version("my.subject", 42)

      assert status == :ok
      assert response == %{"id" => 42, "schema" => ~s({"hello":"world"})}
    end

    test "when request was unsuccessful" do
      SchemaRegistry.HttpClientMock
      |> expect(:get, fn url ->
        assert url == "subjects/my.subject/versions/42"

        {:error, "Something went wrong!"}
      end)

      {status, response} = SchemaRegistry.version("my.subject", 42)

      assert status == :error
      assert response == "Something went wrong!"
    end
  end

  describe "schema/1" do
    test "when request was successful" do
      SchemaRegistry.HttpClientMock
      |> expect(:get, fn url ->
        assert url == "schemas/ids/99"

        {:ok, %{"id" => 99, "schema" => ~s({"hello":"world"})}}
      end)

      {status, response} = SchemaRegistry.schema(99)

      assert status == :ok
      assert response == %{"id" => 99, "schema" => ~s({"hello":"world"})}
    end

    test "when request was unsuccessful" do
      SchemaRegistry.HttpClientMock
      |> expect(:get, fn url ->
        assert url == "schemas/ids/99"

        {:error, "Something went wrong!"}
      end)

      {status, response} = SchemaRegistry.schema(99)

      assert status == :error
      assert response == "Something went wrong!"
    end
  end

  describe "register/2" do
    test "when request was successful" do
      SchemaRegistry.HttpClientMock
      |> expect(:post, fn url, payload ->
        assert url == "subjects/my.subject/versions"
        assert payload == %{"hello" => "world"}

        {:ok, %{"id" => 1}}
      end)

      {status, response} = SchemaRegistry.register("my.subject", %{"hello" => "world"})

      assert status == :ok
      assert response == %{"id" => 1}
    end

    test "when request was unsuccessful" do
      SchemaRegistry.HttpClientMock
      |> expect(:post, fn url, payload ->
        assert url == "subjects/my.subject/versions"
        assert payload == %{"hello" => "world"}

        {:error, "Something went wrong!"}
      end)

      {status, response} = SchemaRegistry.register("my.subject", %{"hello" => "world"})

      assert status == :error
      assert response == "Something went wrong!"
    end
  end
end
