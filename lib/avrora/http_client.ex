defmodule Avrora.HTTPClient do
  @moduledoc """
  Minimalistic HTTP client with a get/post functionality and built-in
  JSON encode/decode behaviour.
  """

  @callback get(String.t()) :: {:ok, map()} | {:error, term()}
  @callback post(String.t(), String.t(), keyword(String.t())) :: {:ok, map()} | {:error, term()}

  @doc false
  @spec get(String.t()) :: {:ok, map()} | {:error, term()}
  def get(url) do
    case :httpc.request(:get, {'#{url}', []}, [], []) do
      {:ok, {{_, status, _}, _, body}} ->
        handle(status, body)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  @spec post(String.t(), String.t(), keyword(String.t())) :: {:ok, map()} | {:error, term()}
  def post(url, payload, content_type: content_type) when is_binary(payload) do
    with {:ok, body} <- Jason.encode(%{"schema" => payload}),
         {:ok, {{_, status, _}, _, body}} =
           :httpc.request(:post, {'#{url}', [], [content_type], body}, [], []) do
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
end
