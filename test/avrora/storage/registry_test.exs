defmodule Avrora.Storage.RegistryTest do
  use ExUnit.Case, async: true
  doctest Avrora.Storage.Registry

  import Mox
  import ExUnit.CaptureLog
  alias Avrora.Storage.Registry

  setup :verify_on_exit!

  describe "get/1" do
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

    test "when request by global ID was unsuccessful" do
      Avrora.HTTPClientMock
      |> expect(:get, fn url, _ ->
        assert url == "http://reg.loc/schemas/ids/1"

        {:error, version_not_found_parsed_error()}
      end)

      assert Registry.get(1) == {:error, :unknown_version}
    end

    test "when registry url is unconfigured" do
      registry_url = Application.get_env(:avrora, :registry_url)
      Application.put_env(:avrora, :registry_url, nil)

      assert Registry.get("anything") == {:error, :unconfigured_registry_url}

      Application.put_env(:avrora, :registry_url, registry_url)
    end
  end

  describe "put/2" do
    test "when request was successful" do
      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, _ ->
        assert url == "http://reg.loc/subjects/io.confluent.Payment/versions"
        assert payload == json_schema()

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

    test "when registry url is unconfigured" do
      registry_url = Application.get_env(:avrora, :registry_url)
      Application.put_env(:avrora, :registry_url, nil)

      assert Registry.put("anything", ~s({"type":"string"})) ==
               {:error, :unconfigured_registry_url}

      Application.put_env(:avrora, :registry_url, registry_url)
    end

    test "when registry auth is malformed" do
      registry_auth = Application.get_env(:avrora, :registry_auth)
      Application.put_env(:avrora, :registry_auth, {:basic, "user", "pass", "unknown"})

      assert Registry.put("anything", ~s({"type":"string"})) == {:error, :malformed_registry_auth}

      Application.put_env(:avrora, :registry_auth, registry_auth)
    end

    test "when registry auth file not exists" do
      registry_auth = Application.get_env(:avrora, :registry_auth)
      Application.put_env(:avrora, :registry_auth, {:basic, "unknown"})

      output =
        capture_log(fn ->
          assert Registry.put("anything", ~s({"type":"string"})) ==
                   {:error, :no_such_registry_auth_file}
        end)

      output =~ "no such registry auth file found unknown"

      Application.put_env(:avrora, :registry_auth, registry_auth)
    end

    test "when registry auth basic file is configured" do
      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, headers: headers, content_type: _ ->
        base64 = :base64.encode_to_string("avrora_username:avrora_password")

        assert url == "https://reg.loc/subjects/io.confluent.Payment/versions"
        assert payload == json_schema()
        assert headers == [{'Authorization', 'Basic #{base64}'}]

        {:ok, %{"id" => 1}}
      end)

      registry_url = Application.get_env(:avrora, :registry_url)
      registry_auth = Application.get_env(:avrora, :registry_auth)
      Application.put_env(:avrora, :registry_url, "https://reg.loc")
      Application.put_env(:avrora, :registry_auth, {:basic, "./test/fixtures/auth"})

      {:ok, schema} = Registry.put("io.confluent.Payment", json_schema())

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"

      Application.put_env(:avrora, :registry_url, registry_url)
      Application.put_env(:avrora, :registry_auth, registry_auth)
    end

    test "when registry auth basic is configured" do
      Avrora.HTTPClientMock
      |> expect(:post, fn url, payload, headers: headers, content_type: _ ->
        base64 = :base64.encode_to_string("avrora_username:avrora_password")

        assert url == "https://reg.loc/subjects/io.confluent.Payment/versions"
        assert payload == json_schema()
        assert headers == [{'Authorization', 'Basic #{base64}'}]

        {:ok, %{"id" => 1}}
      end)

      registry_url = Application.get_env(:avrora, :registry_url)
      registry_auth = Application.get_env(:avrora, :registry_auth)
      Application.put_env(:avrora, :registry_url, "https://reg.loc")
      Application.put_env(:avrora, :registry_auth, {:basic, "avrora_username", "avrora_password"})

      {:ok, schema} = Registry.put("io.confluent.Payment", json_schema())

      assert schema.id == 1
      assert is_nil(schema.version)
      assert schema.full_name == "io.confluent.Payment"

      Application.put_env(:avrora, :registry_url, registry_url)
      Application.put_env(:avrora, :registry_auth, registry_auth)
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
end
