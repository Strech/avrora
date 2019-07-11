defmodule Avrora.Config do
  @moduledoc """
  Configuration for Avrora with some extra options.

  ## Available options:

      * `schemas_path` a path where all local schemas stored (default: ./priv/schemas)
      * `registry_url` a Confluent Schema Registry url (default: nil)

  ## Extra settings:

      * `file_storage` implements `Storage` behaviour and handle files in `schemas_path`
      * `memory_storage` implements `Storage` behaviour and handle memory operations
      * `registry_storage` implements `Storage` behaviour and handle Schema Registry via `registry_url`
      * `http_client` a basic HTTP client for the get/post requests
  """

  @doc false
  def schemas_path, do: get_env(:schemas_path, Path.expand("../../priv/schemas"))

  @doc false
  def registry_url, do: get_env(:registry_url, nil)

  @doc false
  def file_storage, do: get_env(:file_storage, Avrora.Storage.File)

  @doc false
  def memory_storage, do: get_env(:memory_storage, Avrora.Storage.Memory)

  @doc false
  def registry_storage, do: get_env(:registry_storage, Avrora.Storage.Registry)

  @doc false
  def http_client, do: get_env(:http_client, Avrora.HttpClient)

  defp get_env(name, default), do: Application.get_env(:avrora, name, default)
end
