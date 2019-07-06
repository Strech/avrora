Application.put_env(:avrora, :http_client, Avrora.SchemaRegistry.HttpClientMock)
Application.put_env(:avrora, :registry_url, "http://reg.loc")

ExUnit.start()
