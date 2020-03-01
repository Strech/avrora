defmodule Avrora.HTTPClient do
  @moduledoc """
  Minimal HTTP client using built-in Erlang `httpc` library.
  """

  @callback get(String.t(), keyword(String.t())) :: {:ok, map()} | {:error, term()}
  @callback post(String.t(), String.t(), keyword(String.t())) :: {:ok, map()} | {:error, term()}

  @doc false
  @spec get(String.t(), keyword(String.t())) :: {:ok, map()} | {:error, term()}
  def get(url, headers: headers) do
    case :httpc.request(:get, {'#{url}', headers}, [], []) do
      {:ok, {{_, status, _}, _, body}} ->
        handle(status, body)

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc false
  @spec post(String.t(), String.t(), keyword(String.t())) :: {:ok, map()} | {:error, term()}
  def post(url, payload, headers: headers, content_type: content_type) when is_binary(payload) do
    with {:ok, body} <- Jason.encode(%{"schema" => payload}),
         {:ok, {{_, status, _}, _, body}} <-
           :httpc.request(:post, {'#{url}', headers, [content_type], body}, [], []) do
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
