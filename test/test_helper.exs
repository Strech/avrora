# Application.put_env(:avrora, :http_client, Avrora.HTTPClientMock)
# Application.put_env(:avrora, :file_storage, Avrora.Storage.FileMock)
# Application.put_env(:avrora, :memory_storage, Avrora.Storage.MemoryMock)
# Application.put_env(:avrora, :registry_storage, Avrora.Storage.RegistryMock)
# Application.put_env(:avrora, :ets_lib, :avro_schema_store)
Application.put_env(:avrora, :config, Avrora.ConfigMock)

# Application.put_env(:avrora, :registry_url, "http://reg.loc")
# Application.put_env(:avrora, :registry_auth, nil)
# Application.put_env(:avrora, :schemas_path, Path.expand("./test/fixtures/schemas"))
# Application.put_env(:avrora, :names_cache_ttl, :infinity)

ExUnit.start(capture_log: true)
