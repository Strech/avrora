defmodule Avrora.RegistryStorageTest do
  use ExUnit.Case, async: true
  doctest Avrora.RegistryStorage

  import Mox
  alias Avrora.RegistryStorage

  setup :verify_on_exit!

  describe "get/1" do
    test "when request by subject name without version was successful" do
      RegistryStorage.HttpClientMock
      |> expect(:get, fn url ->
        assert url == "subjects/io.confluent.Payment/versions/latest"

        {
          :ok,
          %{
            "name" => "io.confluent.Payment",
            "version" => 1,
            "schema" => payment_schema()
          }
        }
      end)

      {:ok, avro} = RegistryStorage.get("io.confluent.Payment")

      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert length(avro.ex_schema.schema.fields) == 2
      assert length(Map.get(avro.raw_schema, "fields")) == 2
    end

    test "when request by subject name with version was successful" do
      RegistryStorage.HttpClientMock
      |> expect(:get, fn url ->
        assert url == "subjects/io.confluent.Payment/versions/10"

        {
          :ok,
          %{
            "name" => "io.confluent.Payment",
            "version" => 10,
            "schema" => payment_schema()
          }
        }
      end)

      {:ok, avro} = RegistryStorage.get("io.confluent.Payment:10")

      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert length(avro.ex_schema.schema.fields) == 2
      assert length(Map.get(avro.raw_schema, "fields")) == 2
    end

    test "when request by subject name was unsuccessful" do
      RegistryStorage.HttpClientMock
      |> expect(:get, fn url ->
        assert url == "subjects/io.confluent.Payment/versions/latest"

        {:error, subject_not_found_parsed_error()}
      end)

      {:error, response} = RegistryStorage.get("io.confluent.Payment")
      assert response == %{"error_code" => 40401, "message" => "Subject not found!"}
    end

    test "when request by global ID was successful" do
      RegistryStorage.HttpClientMock
      |> expect(:get, fn url ->
        assert url == "schemas/ids/1"

        {:ok, %{"schema" => payment_schema()}}
      end)

      {:ok, avro} = RegistryStorage.get(1)

      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert length(avro.ex_schema.schema.fields) == 2
      assert length(Map.get(avro.raw_schema, "fields")) == 2
    end

    test "when request by global ID was unsuccessful" do
      RegistryStorage.HttpClientMock
      |> expect(:get, fn url ->
        assert url == "schemas/ids/1"

        {:error, version_not_found_parsed_error()}
      end)

      {:error, response} = RegistryStorage.get(1)
      assert response == %{"error_code" => 40402, "message" => "Subject version not found!"}
    end
  end

  describe "put/2" do
    test "when value is parsed json and request was successful" do
      RegistryStorage.HttpClientMock
      |> expect(:post, fn url, payload ->
        assert url == "subjects/io.confluent.Payment/versions"
        assert payload == parsed_payment_schema()

        {
          :ok,
          %{"id" => 1}
        }
      end)

      {:ok, avro} = RegistryStorage.put("io.confluent.Payment", parsed_payment_schema())

      assert avro.id == 1
      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert avro.raw_schema == parsed_payment_schema()
    end

    test "when value is raw json and request was successful" do
      RegistryStorage.HttpClientMock
      |> expect(:post, fn url, payload ->
        assert url == "subjects/io.confluent.Payment/versions"
        assert payload == payment_schema()

        {
          :ok,
          %{"id" => 1}
        }
      end)

      {:ok, avro} = RegistryStorage.put("io.confluent.Payment", payment_schema())

      assert avro.id == 1
      assert avro.ex_schema.schema.qualified_names == ["io.confluent.Payment"]
      assert avro.raw_schema == parsed_payment_schema()
    end

    test "when request was unsuccessful" do
      RegistryStorage.HttpClientMock
      |> expect(:post, fn url, payload ->
        assert url == "subjects/io.confluent.Payment/versions"
        assert payload == %{"type" => "string"}

        {:error, schema_incompatible_parsed_error()}
      end)

      {:error, reason} = RegistryStorage.put("io.confluent.Payment", %{"type" => "string"})

      assert reason == %{"error_code" => 409, "message" => "Schema is incompatible!"}
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

  defp parsed_payment_schema do
    %{
      "namespace" => "io.confluent",
      "type" => "record",
      "name" => "Payment",
      "fields" => [
        %{"name" => "id", "type" => "string"},
        %{"name" => "amount", "type" => "double"}
      ]
    }
  end

  defp payment_schema do
    ~s({"namespace":"io.confluent","type":"record","name":"Payment","fields":[{"name":"id","type":"string"},{"name":"amount","type":"double"}]})
  end
end
