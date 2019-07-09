Application.put_env(:avrora, :http_client, Avrora.HttpClientMock)
Application.put_env(:avrora, :file_storage, Avrora.FileStorageMock)
Application.put_env(:avrora, :memory_storage, Avrora.MemoryStorageMock)
Application.put_env(:avrora, :registry_storage, Avrora.RegistryStorageMock)

Application.put_env(:avrora, :registry_url, "http://reg.loc")
Application.put_env(:avrora, :schemas_path, Path.expand("./test/fixtures/schemas"))

ExUnit.start()
