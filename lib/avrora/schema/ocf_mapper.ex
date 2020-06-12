defmodule Avrora.Schema.OCFMapper do
  @moduledoc """
  Function to parse erlavro tuple schema to struct
  """

  @doc """
  Convert schema tuple-based structure returned by erlavro to Elixir map.
  ## Examples
      iex> test = {:avro_record_type, "Payment", "io.confluent", "", [],
      ...>  [
      ...>    {:avro_record_field, "id", "", {:avro_primitive_type, "string", []},
      ...>     :undefined, :ascending, []},
      ...>    {:avro_record_field, "amount", "", {:avro_primitive_type, "double", []},
      ...>     :undefined, :ascending, []}
      ...>  ], "io.confluent.Payment", []}
      iex> Avrora.Schema.OFCMapper.parse(test)
      %{
        fields: [%{name: "id", type: "string"}, %{name: "amount", type: "double"}],
        namespace: "io.confluent",
        name: "Payment",
        type: "record"
      }
  """
  @spec parse(
    {:avro_record_field, String.t(), any, {any, String.t(), any}, any, any, any}
    | {:avro_record_type, any, String.t(), any, any, List.t(), any, any}
  ) :: map()
  def parse({:avro_record_type, name, namespace, _, _, fields, _, _}) do
    %{}
        |> Map.put(:namespace, namespace)
        |> Map.put(:name, name)
        |> Map.put(:type, "record")
        |> Map.put(:fields, Enum.map(fields, &parse/1))
  end

  def parse({:avro_record_field, name, _, {_, type, _} = _field_type, _, _, _}) do
      %{}
        |> Map.put(:name, name)
        |> Map.put(:type, type)
  end
end
