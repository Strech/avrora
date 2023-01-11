defmodule Avrora.HTTPClient do
  @moduledoc """
  Minimal HTTP client using built-in Erlang `httpc` library.
  """

  @callback get(String.t(), keyword(String.t())) :: {:ok, map()} | {:error, term()}
  @callback post(String.t(), String.t(), keyword(String.t())) :: {:ok, map()} | {:error, term()}

  @doc false
  @spec get(String.t(), keyword(String.t())) :: {:ok, map()} | {:error, term()}
  def get(url, options \\ []) do
    with {:ok, headers} <- extract_headers(options),
         {:ok, {{_, status, _}, _, body}} <- :httpc.request(:get, {'#{url}', headers}, [ssl: ssl_options()], []) do
      handle(status, body)
    end
  end

  @doc false
  @spec post(String.t(), String.t(), keyword(String.t())) :: {:ok, map()} | {:error, term()}
  def post(url, payload, options \\ []) when is_binary(payload) do
    with {:ok, body} <- Jason.encode(%{"schema" => payload}),
         {:ok, content_type} <- Keyword.fetch(options, :content_type),
         {:ok, headers} <- extract_headers(options),
         {:ok, {{_, status, _}, _, body}} <-
           :httpc.request(:post, {'#{url}', headers, [content_type], body}, [ssl: ssl_options()], []) do
      handle(status, body)
    end
  end

  defp extract_headers(options) do
    authorization =
      case Keyword.get(options, :authorization) do
        nil -> []
        credentials -> [{'Authorization', '#{credentials}'}]
      end

    case Keyword.get(options, :user_agent) do
      nil -> {:ok, authorization}
      user_agent -> {:ok, [{'User-Agent', '#{user_agent}'} | authorization]}
    end
  end

  defp handle(200 = _status, body), do: Jason.decode(body)

  defp handle(status, body) do
    case Jason.decode(body) do
      {:ok, reason} -> {:error, reason}
      {:error, _} -> {:error, {status, body}}
    end
  end

  defp ssl_options, do: [verify: :verify_none]
end
