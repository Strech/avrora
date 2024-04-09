defmodule Avrora.Storage.RegistryTest do
  # NOTE: Remove when Elixir 1.6 support ends
  use ExUnit.Case
  # use ExUnit.Case, async: true
  doctest Avrora.Storage.Registry

  import Mox
  import Support.Config
  import ExUnit.CaptureLog
  alias Avrora.Storage.Registry

  # NOTE: Remove when Elixir 1.6 support ends
  setup :set_mox_from_context

  setup :verify_on_exit!
  setup :support_config

  describe "get/1" do
    test "when request by subject name of schema with reference without version was successful" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.confluent.Account/versions/latest"

        {
          :ok,
          %{
            "subject" => "io.confluent.Account",
            "id" => 43,
            "version" => 1,
            "schema" => json_schema_with_reference(),
            "references" => [
              %{"name" => "io.confluent.User", "subject" => "io.confluent.User", "version" => 1}
            ]
          }
        }
      end)

      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.confluent.User/versions/1"

        {
          :ok,
          %{
            "subject" => "io.confluent.User",
            "id" => 44,
            "version" => 1,
            "schema" => json_schema_referenced()
          }
        }
      end)

      {:ok, schema} = Registry.get("io.confluent.Account")

      assert schema.id == 43
      assert schema.version == 1
      assert schema.full_name == "io.confluent.Account"
      assert schema.json == json_schema_with_reference_denormalized()
    end

    test "when request by subject name of schema with reference was unsuccessful because of reference schema not found" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.confluent.Account/versions/latest"

        {
          :ok,
          %{
            "subject" => "io.confluent.Account",
            "id" => 43,
            "version" => 1,
            "schema" => json_schema_with_reference(),
            "references" => [
              %{
                "name" => "io.confluent.Unexisting",
                "subject" => "io.confluent.Unexisting"
              }
            ]
          }
        }
      end)

      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.confluent.Unexisting/versions/latest"

        {:error, subject_not_found_parsed_error()}
      end)

      assert Registry.get("io.confluent.Account") == {:error, :unknown_reference_subject}
    end

    test "when request by subject name without version was successful" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.confluent.Payment/versions/latest"

        {
          :ok,
          %{
            "subject" => "io.confluent.Payment",
            "id" => 42,
            "version" => 1,
            "schema" => json_schema()
          }
        }
      end)

      {:ok, schema} = Registry.get("io.confluent.Payment")

      assert schema.id == 42
      assert schema.version == 1
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when request by subject name with version was successful" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.confluent.Payment/versions/10"

        {
          :ok,
          %{
            "subject" => "io.confluent.Payment",
            "id" => 42,
            "version" => 10,
            "schema" => json_schema()
          }
        }
      end)

      {:ok, schema} = Registry.get("io.confluent.Payment:10")

      assert schema.id == 42
      assert schema.version == 10
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when request by subject name was unsuccessful" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.confluent.Payment/versions/latest"

        {:error, subject_not_found_parsed_error()}
      end)

      assert Registry.get("io.confluent.Payment") == {:error, :unknown_subject}
    end

    test "when request by global ID was successful" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/schemas/ids/1"

        {:ok, %{"schema" => json_schema()}}
      end)

      {:ok, schema} = Registry.get(1)

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when request by global ID with basic auth was successful" do
      stub(Avrora.ConfigMock, :registry_auth, fn -> {:basic, ["login", "password"]} end)

      Avrora.HTTPClientMock
      |> expect(:get, fn url, options ->
        assert url == "http://reg.loc/schemas/ids/1"
        assert Keyword.fetch!(options, :authorization) == "Basic bG9naW46cGFzc3dvcmQ="

        {:ok, %{"schema" => json_schema()}}
      end)

      {:ok, schema} = Registry.get(1)

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when request by global ID was unsuccessful" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/schemas/ids/1"

        {:error, version_not_found_parsed_error()}
      end)

      assert Registry.get(1) == {:error, :unknown_version}
    end

    test "when request by global ID with reference was successful" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/schemas/ids/43"

        {
          :ok,
          %{
            "subject" => "io.confluent.Account",
            "id" => 43,
            "version" => 1,
            "schema" => json_schema_with_reference(),
            "references" => [
              %{"name" => "io.confluent.User", "subject" => "io.confluent.User", "version" => 1}
            ]
          }
        }
      end)

      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.confluent.User/versions/1"

        {
          :ok,
          %{
            "subject" => "io.confluent.User",
            "id" => 44,
            "version" => 1,
            "schema" => json_schema_referenced()
          }
        }
      end)

      {:ok, schema} = Registry.get(43)

      assert schema.id == 43
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Account"
      assert schema.json == json_schema_with_reference_denormalized()
    end

    test "when request should not perform SSL verification" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, options ->
        assert url == "http://reg.loc/schemas/ids/1"
        assert Keyword.fetch!(options, :ssl_options) == [verify: :verify_none]

        {:ok, %{"schema" => json_schema()}}
      end)

      {:ok, schema} = Registry.get(1)

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when request should not perform SSL verification based on given cert" do
      stub(Avrora.ConfigMock, :registry_ssl_cacerts, fn -> <<48, 130, 3, 201>> end)
      stub(Avrora.ConfigMock, :registry_ssl_cacertfile, fn -> "path/to/file" end)

      Avrora.HTTPClientMock
      |> expect(:get, fn url, options ->
        assert url == "http://reg.loc/schemas/ids/1"
        assert Keyword.fetch!(options, :ssl_options) == [verify: :verify_peer, cacerts: [<<48, 130, 3, 201>>]]

        {:ok, %{"schema" => json_schema()}}
      end)

      assert :ok == Registry.get(1) |> elem(0)
    end

    test "when request should not perform SSL verification based on given cert file" do
      stub(Avrora.ConfigMock, :registry_ssl_cacertfile, fn -> "path/to/file" end)

      Avrora.HTTPClientMock
      |> expect(:get, fn url, options ->
        assert url == "http://reg.loc/schemas/ids/1"
        assert Keyword.fetch!(options, :ssl_options) == [verify: :verify_peer, cacertfile: "path/to/file"]

        {:ok, %{"schema" => json_schema()}}
      end)

      assert :ok == Registry.get(1) |> elem(0)
    end

    test "when registry url is unconfigured" do
      stub(Avrora.ConfigMock, :registry_url, fn -> nil end)

      assert Registry.get("anything") == {:error, :unconfigured_registry_url}
    end
  end

  describe "put/2" do
    test "when request was successful" do
      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, options ->
        assert url == "http://reg.loc/subjects/io.confluent.Payment/versions"
        assert payload == json_schema()
        assert Keyword.fetch!(options, :content_type) == "application/vnd.schemaregistry.v1+json"
        assert Keyword.fetch!(options, :ssl_options) == [verify: :verify_none]

        {:ok, %{"id" => 1}}
      end)

      {:ok, schema} = Registry.put("io.confluent.Payment", json_schema())

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"
    end

    test "when key contains version and request was successful" do
      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, _ ->
        assert url == "http://reg.loc/subjects/io.confluent.Payment/versions"
        assert payload == json_schema()

        {:ok, %{"id" => 1}}
      end)

      output =
        capture_log(fn ->
          {:ok, schema} = Registry.put("io.confluent.Payment:42", json_schema())

          assert schema.id == 1
          assert is_nil(schema.version)
          assert schema.full_name == "io.confluent.Payment"
        end)

      assert output =~ "schema with version is not allowed"
    end

    test "when request was unsuccessful" do
      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, _ ->
        assert url == "http://reg.loc/subjects/io.confluent.Payment/versions"
        assert payload == ~s({"type":"string"})

        {:error, schema_incompatible_parsed_error()}
      end)

      assert Registry.put("io.confluent.Payment", ~s({"type":"string"})) == {:error, :conflict}
    end

    test "when request should send Authorization header" do
      stub(Avrora.ConfigMock, :registry_auth, fn -> {:basic, ["login", "password"]} end)

      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, options ->
        assert url == "http://reg.loc/subjects/io.confluent.Payment/versions"
        assert payload == json_schema()
        assert Keyword.fetch!(options, :authorization) == "Basic bG9naW46cGFzc3dvcmQ="

        {:ok, %{"id" => 1}}
      end)

      assert :ok == Registry.put("io.confluent.Payment", json_schema()) |> elem(0)
    end

    test "when request should send User-Agent header" do
      stub(Avrora.ConfigMock, :registry_user_agent, fn -> "Avrora/0.0.1 Elixir" end)

      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, options ->
        assert url == "http://reg.loc/subjects/io.confluent.Payment/versions"
        assert payload == json_schema()
        assert Keyword.fetch!(options, :user_agent) == "Avrora/0.0.1 Elixir"

        {:ok, %{"id" => 1}}
      end)

      assert :ok == Registry.put("io.confluent.Payment", json_schema()) |> elem(0)
    end

    test "when request should not perform SSL verification based on given cert" do
      stub(Avrora.ConfigMock, :registry_ssl_cacerts, fn -> <<48, 130, 3, 201>> end)
      stub(Avrora.ConfigMock, :registry_ssl_cacertfile, fn -> "path/to/file" end)

      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, options ->
        assert url == "http://reg.loc/subjects/io.confluent.Payment/versions"
        assert payload == json_schema()
        assert Keyword.fetch!(options, :ssl_options) == [verify: :verify_peer, cacerts: [<<48, 130, 3, 201>>]]

        {:ok, %{"id" => 1}}
      end)

      assert :ok == Registry.put("io.confluent.Payment", json_schema()) |> elem(0)
    end

    test "when request should not perform SSL verification based on given cert file" do
      stub(Avrora.ConfigMock, :registry_ssl_cacertfile, fn -> "path/to/file" end)

      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, options ->
        assert url == "http://reg.loc/subjects/io.confluent.Payment/versions"
        assert payload == json_schema()
        assert Keyword.fetch!(options, :ssl_options) == [verify: :verify_peer, cacertfile: "path/to/file"]

        {:ok, %{"id" => 1}}
      end)

      assert :ok == Registry.put("io.confluent.Payment", json_schema()) |> elem(0)
    end

    test "when registry url is unconfigured" do
      stub(Avrora.ConfigMock, :registry_url, fn -> nil end)

      assert Registry.put("anything", ~s({"type":"string"})) == {:error, :unconfigured_registry_url}
    end
  end

  defp subject_not_found_parsed_error do
    %{"error_code" => 40401, "message" => "Subject not found!"}
  end

  defp version_not_found_parsed_error do
    %{"error_code" => 40402, "message" => "Subject version not found!"}
  end

  defp schema_incompatible_parsed_error do
    %{"error_code" => 409, "message" => "Schema is incompatible!"}
  end

  defp json_schema do
    ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end

  defp json_schema_with_reference do
    ~s({"namespace":"io.confluent","type":"record","name":"Account","fields":[{"name":"id","type":"string"},{"name":"user","type":"User"}]})
  end

  defp json_schema_with_reference_denormalized do
    nested_schema =
      ~s({"name":"User","type":"record","fields":[{"name":"id","type":"string"},{"name":"username","type":"string"}]})

    ~s({"namespace":"io.confluent","name":"Account","type":"record","fields":[{"name":"id","type":"string"},{"name":"user","type":#{nested_schema}}]})
  end

  defp json_schema_referenced do
    ~s({"namespace":"io.confluent","type":"record","name":"User","fields":[{"name":"id","type":"string"},{"name":"username","type":"string"}]})
  end
end
