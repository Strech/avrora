defmodule Avrora.ObjectContainerFile do
  @moduledoc """
  A wrapper around `erlavro` Object Container File module.
  """

  alias Avrora.{Config, Schema}

  @meta_schema_key "avro.schema"

  @doc """
  Extract schema from the Object Container File formatted message.

  ## Examples

      ...> payload = <<79, 98, 106, 1, 3, 204, 2, 20, 97, 118, 114, 111, 46, 99, 111, 100, 101, 99, 8,
      110, 117, 108, 108, 22, 97, 118, 114, 111, 46, 115, 99, 104, 101, 109, 97, 144, 2, 123, 34, 110,
      97, 109, 101, 115, 112, 97, 99, 101, 34, 58, 34, 105, 111, 46, 99, 111, 110, 102, 108, 117, 101,
      110, 116, 34, 44, 34, 110, 97, 109, 101, 34, 58, 34, 80, 97, 121, 109, 101, 110, 116, 34,
      44, 34, 116, 121, 112, 101, 34, 58, 34, 114, 101, 99, 111, 114, 100, 34, 44, 34, 102, 105,
      101, 108, 100, 115, 34, 58, 91, 123, 34, 110, 97, 109, 101, 34, 58, 34, 105, 100, 34, 44,
      34, 116, 121, 112, 101, 34, 58, 34, 115, 116, 114, 105, 110, 103, 34, 125, 44, 123, 34, 110,
      97, 109, 101, 34, 58, 34, 97, 109, 111, 117, 110, 116, 34, 44, 34, 116, 121, 112, 101, 34,
      58, 34, 100, 111, 117, 98, 108, 101, 34, 125, 93, 125, 0, 236, 47, 96, 164, 206, 59, 152,
      115, 80, 243, 64, 50, 180, 153, 105, 34, 2, 90, 72, 48, 48, 48, 48, 48, 48, 48, 48, 45, 48,
      48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 45, 48, 48, 48, 48, 48, 48, 48, 48, 48,
      48, 48, 48, 123, 20, 174, 71, 225, 250, 47, 64, 236, 47, 96, 164, 206, 59, 152, 115, 80,
      243, 64, 50, 180, 153, 105, 34>>
      ...> {:ok, schema} = Avrora.ObjectContainerFile.extract_schema(payload)
      ...> schema.full_name
      "io.confluent.Payment"
      ...> schema.id
      nil
  """

  @spec extract_schema(binary()) :: {:ok, Schema.t()} | {:error, term()}
  def extract_schema(payload) when is_binary(payload) do
    with {:ok, {headers, {_, _, _, _, _, _, full_name, _} = erlavro, _}} <- do_decode(payload),
         {:ok, nil} <- memory_storage().get(full_name),
         {:ok, json} <- extract_json_schema(headers),
         {:ok, schema} <- Schema.from_erlavro(erlavro, json: json) do
      memory_storage().put(full_name, schema)
    end
  end

  defp do_decode(payload) do
    {:ok, :avro_ocf.decode_binary(payload)}
  rescue
    error -> {:error, error}
  end

  defp extract_json_schema(headers) do
    with {_, _, meta, _} <- headers,
         {@meta_schema_key, json} <- Enum.find(meta, fn {key, _} -> key == @meta_schema_key end) do
      {:ok, json}
    end
  end

  defp memory_storage, do: Config.self().memory_storage()
end
