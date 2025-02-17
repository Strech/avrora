defmodule Avrora.Storage.RegistryTest do
  use ExUnit.Case, async: true
  doctest Avrora.Storage.Registry

  import Mox
  import Support.Config
  import ExUnit.CaptureLog
  alias Avrora.Storage.Registry

  setup :verify_on_exit!
  setup :support_config

  describe "get/1" do
    test "when requesting by subject name without version and schema contains external reference" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.acme.Account/versions/latest"

        {
          :ok,
          %{
            "subject" => "io.acme.Account",
            "id" => 43,
            "version" => 1,
            "schema" => json_schema_with_reference(),
            "references" => [
              %{"name" => "io.acme.User", "subject" => "io.acme.User", "version" => 1}
            ]
          }
        }
      end)

      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.acme.User/versions/1"

        {
          :ok,
          %{
            "subject" => "io.acme.User",
            "id" => 44,
            "version" => 1,
            "schema" => json_schema_referenced()
          }
        }
      end)

      {:ok, schema} = Registry.get("io.acme.Account")

      assert schema.id == 43
      assert schema.version == 1
      assert schema.full_name == "io.acme.Account"
      assert schema.json == json_schema_with_reference_denormalized()
    end

    test "when requesting by subject name and external reference schema not found" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.acme.Account/versions/latest"

        {
          :ok,
          %{
            "subject" => "io.acme.Account",
            "id" => 43,
            "version" => 1,
            "schema" => json_schema_with_reference(),
            "references" => [
              %{
                "name" => "io.acme.Unexisting",
                "subject" => "io.acme.Unexisting"
              }
            ]
          }
        }
      end)

      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.acme.Unexisting/versions/latest"

        {:error, subject_not_found_parsed_error()}
      end)

      assert Registry.get("io.acme.Account") == {:error, :unknown_reference_subject}
    end

    test "when requesting by subject name without version" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.acme.Payment/versions/latest"

        {
          :ok,
          %{
            "subject" => "io.acme.Payment",
            "id" => 42,
            "version" => 1,
            "schema" => json_schema()
          }
        }
      end)

      {:ok, schema} = Registry.get("io.acme.Payment")

      assert schema.id == 42
      assert schema.version == 1
      assert schema.full_name == "io.acme.Payment"
    end

    test "when requesting by subject name with version" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.acme.Payment/versions/10"

        {
          :ok,
          %{
            "subject" => "io.acme.Payment",
            "id" => 42,
            "version" => 10,
            "schema" => json_schema()
          }
        }
      end)

      {:ok, schema} = Registry.get("io.acme.Payment:10")

      assert schema.id == 42
      assert schema.version == 10
      assert schema.full_name == "io.acme.Payment"
    end

    test "when requesting by subject name failed" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.acme.Payment/versions/latest"

        {:error, subject_not_found_parsed_error()}
      end)

      assert Registry.get("io.acme.Payment") == {:error, :unknown_subject}
    end

    test "when requesting by global ID" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/schemas/ids/1"

        {:ok, %{"schema" => json_schema()}}
      end)

      {:ok, schema} = Registry.get(1)

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.acme.Payment"
    end

    test "when requesting by global ID with basic auth" do
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
      assert schema.full_name == "io.acme.Payment"
    end

    test "when requesting by global ID was failed" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/schemas/ids/1"

        {:error, version_not_found_parsed_error()}
      end)

      assert Registry.get(1) == {:error, :unknown_version}
    end

    test "when requesting by global ID with reference" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/schemas/ids/43"

        {
          :ok,
          %{
            "subject" => "io.acme.Account",
            "id" => 43,
            "version" => 1,
            "schema" => json_schema_with_reference(),
            "references" => [
              %{"name" => "io.acme.User", "subject" => "io.acme.User", "version" => 1}
            ]
          }
        }
      end)

      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.acme.User/versions/1"

        {
          :ok,
          %{
            "subject" => "io.acme.User",
            "id" => 44,
            "version" => 1,
            "schema" => json_schema_referenced()
          }
        }
      end)

      {:ok, schema} = Registry.get(43)

      assert schema.id == 43
      assert is_nil(schema.version)
      assert schema.full_name == "io.acme.Account"
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
      assert schema.full_name == "io.acme.Payment"
    end

    test "when request should not perform SSL verification based on given cert" do
      stub(Avrora.ConfigMock, :registry_ssl_cacerts, fn -> <<48, 130, 3, 201>> end)
      stub(Avrora.ConfigMock, :registry_ssl_cacert_path, fn -> "path/to/file" end)

      Avrora.HTTPClientMock
      |> expect(:get, fn url, options ->
        assert url == "http://reg.loc/schemas/ids/1"
        assert Keyword.fetch!(options, :ssl_options) == [verify: :verify_peer, cacerts: [<<48, 130, 3, 201>>]]

        {:ok, %{"schema" => json_schema()}}
      end)

      assert :ok == Registry.get(1) |> elem(0)
    end

    test "when request should not perform SSL verification based on given cert file" do
      stub(Avrora.ConfigMock, :registry_ssl_cacert_path, fn -> "path/to/file" end)

      Avrora.HTTPClientMock
      |> expect(:get, fn url, options ->
        assert url == "http://reg.loc/schemas/ids/1"
        assert Keyword.fetch!(options, :ssl_options) == [verify: :verify_peer, cacertfile: "path/to/file"]

        {:ok, %{"schema" => json_schema()}}
      end)

      assert :ok == Registry.get(1) |> elem(0)
    end

    test "when request should perform SSL verification based on given arbitrary SSL options" do
      stub(Avrora.ConfigMock, :registry_ssl_cacert_path, fn -> "path/to/other/file" end)
      stub(Avrora.ConfigMock, :registry_ssl_opts, fn -> [verify: :verify_peer, cacertfile: "path/to/file"] end)

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

    @tag skip: "This test will fail because Registry creates new table on each reference"
    test "when references reuse same ets table" do
      _ = start_link_supervised!(Support.AvroSchemaStore)
      stub(Avrora.ConfigMock, :ets_lib, fn -> Support.AvroSchemaStore end)

      existing_ets_tables = Support.AvroSchemaStore.count()

      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/schemas/ids/43"

        {
          :ok,
          %{
            "subject" => "io.acme.Account",
            "id" => 43,
            "version" => 1,
            "schema" => json_schema_with_reference(),
            "references" => [
              %{"name" => "io.acme.User", "subject" => "io.acme.User", "version" => 1}
            ]
          }
        }
      end)

      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/subjects/io.acme.User/versions/1"

        {
          :ok,
          %{
            "subject" => "io.acme.User",
            "id" => 44,
            "version" => 1,
            "schema" => json_schema_referenced()
          }
        }
      end)

      {:ok, _} = Registry.get(43)

      assert Support.AvroSchemaStore.count() - existing_ets_tables == 1
    end
  end

  describe "put/2" do
    test "when request was successful" do
      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, options ->
        assert url == "http://reg.loc/subjects/io.acme.Payment/versions"
        assert payload == %{schema: json_schema()}
        assert Keyword.fetch!(options, :content_type) == "application/vnd.schemaregistry.v1+json"
        assert Keyword.fetch!(options, :ssl_options) == [verify: :verify_none]

        {:ok, %{"id" => 1}}
      end)

      {:ok, schema} = Registry.put("io.acme.Payment", json_schema())

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.acme.Payment"
    end

    test "when key contains version and request was successful" do
      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, _ ->
        assert url == "http://reg.loc/subjects/io.acme.Payment/versions"
        assert payload == %{schema: json_schema()}

        {:ok, %{"id" => 1}}
      end)

      output =
        capture_log(fn ->
          {:ok, schema} = Registry.put("io.acme.Payment:42", json_schema())

          assert schema.id == 1
          assert is_nil(schema.version)
          assert schema.full_name == "io.acme.Payment"
        end)

      assert output =~ "schema with version is not allowed"
    end

    test "when request was unsuccessful" do
      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, _ ->
        assert url == "http://reg.loc/subjects/io.acme.Payment/versions"
        assert payload == %{schema: ~s({"type":"unknown"})}

        {:error, schema_invalid_parsed_error()}
      end)

      assert Registry.put("io.acme.Payment", ~s({"type":"unknown"})) == {:error, :invalid_schema}
    end

    test "when request should send Authorization header" do
      stub(Avrora.ConfigMock, :registry_auth, fn -> {:basic, ["login", "password"]} end)

      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, options ->
        assert url == "http://reg.loc/subjects/io.acme.Payment/versions"
        assert payload == %{schema: json_schema()}
        assert Keyword.fetch!(options, :authorization) == "Basic bG9naW46cGFzc3dvcmQ="

        {:ok, %{"id" => 1}}
      end)

      assert :ok == Registry.put("io.acme.Payment", json_schema()) |> elem(0)
    end

    test "when request should send User-Agent header" do
      stub(Avrora.ConfigMock, :registry_user_agent, fn -> "Avrora/0.0.1 Elixir" end)

      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, options ->
        assert url == "http://reg.loc/subjects/io.acme.Payment/versions"
        assert payload == %{schema: json_schema()}
        assert Keyword.fetch!(options, :user_agent) == "Avrora/0.0.1 Elixir"

        {:ok, %{"id" => 1}}
      end)

      assert :ok == Registry.put("io.acme.Payment", json_schema()) |> elem(0)
    end

    test "when request should not perform SSL verification based on given cert" do
      stub(Avrora.ConfigMock, :registry_ssl_cacerts, fn -> <<48, 130, 3, 201>> end)
      stub(Avrora.ConfigMock, :registry_ssl_cacert_path, fn -> "path/to/file" end)

      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, options ->
        assert url == "http://reg.loc/subjects/io.acme.Payment/versions"
        assert payload == %{schema: json_schema()}
        assert Keyword.fetch!(options, :ssl_options) == [verify: :verify_peer, cacerts: [<<48, 130, 3, 201>>]]

        {:ok, %{"id" => 1}}
      end)

      assert :ok == Registry.put("io.acme.Payment", json_schema()) |> elem(0)
    end

    test "when request should not perform SSL verification based on given cert file" do
      stub(Avrora.ConfigMock, :registry_ssl_cacert_path, fn -> "path/to/file" end)

      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, options ->
        assert url == "http://reg.loc/subjects/io.acme.Payment/versions"
        assert payload == %{schema: json_schema()}
        assert Keyword.fetch!(options, :ssl_options) == [verify: :verify_peer, cacertfile: "path/to/file"]

        {:ok, %{"id" => 1}}
      end)

      assert :ok == Registry.put("io.acme.Payment", json_schema()) |> elem(0)
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

  defp schema_invalid_parsed_error do
    %{"error_code" => 42201, "message" => "Invalid schema!"}
  end

  defp json_schema do
    ~s({"namespace":"io.acme","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end

  defp json_schema_with_reference do
    ~s({"namespace":"io.acme","type":"record","name":"Account","fields":[{"name":"id","type":"string"},{"name":"user","type":"User"}]})
  end

  defp json_schema_with_reference_denormalized do
    nested_schema =
      ~s({"name":"User","type":"record","fields":[{"name":"id","type":"string"},{"name":"username","type":"string"}]})

    ~s({"namespace":"io.acme","name":"Account","type":"record","fields":[{"name":"id","type":"string"},{"name":"user","type":#{nested_schema}}]})
  end

  defp json_schema_referenced do
    ~s({"namespace":"io.acme","type":"record","name":"User","fields":[{"name":"id","type":"string"},{"name":"username","type":"string"}]})
  end
end
