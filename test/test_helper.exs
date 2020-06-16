Mix.shell(Mix.Shell.Process)
Application.put_env(:avrora, :config, Avrora.ConfigMock)

ExUnit.start(capture_log: true)
