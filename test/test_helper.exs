Application.put_env(:avrora, :http_client, Avrora.RegistryStorage.HttpClientMock)
Application.put_env(:avrora, :registry_url, "http://reg.loc")
Application.put_env(:avrora, :schemas_path, Path.expand("./test/fixtures/schemas"))

ExUnit.start()
