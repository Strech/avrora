defmodule Avrora.HTTPClient do
  @moduledoc """
  Minimal HTTP client using built-in Erlang `httpc` library.
  """

  @callback get(String.t(), keyword(String.t())) :: {:ok, map()} | {:error, term()}
  @callback post(String.t(), String.t(), keyword(String.t())) :: {:ok, map()} | {:error, term()}
  @default_ssl_options [verify: :verify_none]

  @doc false
  @spec get(String.t(), keyword(String.t())) :: {:ok, map()} | {:error, term()}
  def get(url, options \\ []) do
    with {:ok, headers} <- extract_headers(options),
         {:ok, ssl_options} <- extract_ssl(options),
         {:ok, {{_, status, _}, _, body}} <- :httpc.request(:get, {~c"#{url}", headers}, [ssl: ssl_options], []) do
      handle(status, body)
    end
  end

  @doc false
  @spec post(String.t(), term(), keyword(String.t())) :: {:ok, map()} | {:error, term()}
  def post(url, payload, options \\ []) when is_binary(payload) do
    with {:ok, body} <- Jason.encode(payload),
         {:ok, content_type} <- Keyword.fetch(options, :content_type),
         {:ok, headers} <- extract_headers(options),
         {:ok, ssl_options} <- extract_ssl(options),
         {:ok, {{_, status, _}, _, body}} <-
           :httpc.request(:post, {~c"#{url}", headers, [content_type], body}, [ssl: ssl_options], []) do
      handle(status, body)
    end
  end

  defp extract_headers(options) do
    authorization =
      case Keyword.get(options, :authorization) do
        nil -> []
        credentials -> [{~c"Authorization", ~c"#{credentials}"}]
      end

    case Keyword.get(options, :user_agent) do
      nil -> {:ok, authorization}
      user_agent -> {:ok, [{~c"User-Agent", ~c"#{user_agent}"} | authorization]}
    end
  end

  defp extract_ssl(options), do: {:ok, Keyword.get(options, :ssl_options, @default_ssl_options)}
  defp handle(200 = _status, body), do: Jason.decode(body)

  defp handle(status, body) do
    case Jason.decode(body) do
      {:ok, reason} -> {:error, reason}
      {:error, _} -> {:error, {status, body}}
    end
  end
end
