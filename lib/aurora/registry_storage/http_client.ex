defmodule Avrora.RegistryStorage.HttpClient do
  @moduledoc """
  Minimalistic HTTP client with a get/post functionality and built-in
  JSON encode/decode behaviour.
  """

  @callback get(String.t()) :: {:ok, map()} | {:error, any()}
  @callback post(String.t(), String.t()) :: {:ok, map()} | {:error, any()}

  @content_type "application/vnd.schemaregistry.v1+json"

  @doc false
  @spec get(String.t()) :: {:ok, map()} | {:error, any()}
  def get(path) do
    case :httpc.request(:get, {url(path), []}, [], []) do
      {:ok, {_, status, _}, _, body} ->
        handle(status, body)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  @spec post(String.t(), map()) :: {:ok, map()} | {:error, any()}
  def post(path, payload) when is_map(payload) do
    with {:ok, schema} <- Jason.encode(payload), do: post(path, schema)
  end

  @doc false
  @spec post(String.t(), String.t()) :: {:ok, map()} | {:error, any()}
  def post(path, payload) when is_binary(payload) do
    with {:ok, body} <- Jason.encode(%{"schema" => payload}),
         {:ok, {_, status, _}, _, body} =
           :httpc.request(:post, {url(path), [], [@content_type], [body]}, [], []) do
      handle(status, body)
    end
  end

  defp handle(200 = _status, body), do: Jason.decode(body)

  defp handle(status, body) do
    case Jason.decode(body) do
      {:ok, reason} -> {:error, reason}
      {:error, _} -> {:error, {status, body}}
    end
  end

  defp url(path) do
    '#{Application.get_env(:avrora, :registry_url)}/#{path}'
  end
end
