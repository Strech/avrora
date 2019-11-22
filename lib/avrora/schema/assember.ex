defmodule Avrora.Schema.Assembler do
  @moduledoc """
  TODO
  """

  alias Avrora.Schema.Definition

  # schema = :avro_json_decoder.decode_schema(File.read!("test/fixtures/schemas/io/confluent/Account.avsc"), allow_bad_references: true)
  # Avrora.Schema.Assembler.assemble(schema, [], fn name -> :avro_json_decoder.decode_schema(File.read!("test/fixtures/schemas/#{String.replace(name, ".", "/")}.avsc"), allow_bad_references: true) end)

  def assemble(schema, definitions, function) do
    {:ok, %{ref: refs, def: defs}} = Definition.extract(schema)

    definitions =
      defs
      |> List.concat(definitions)
      |> Enum.uniq()

    List.foldl(refs -- definitions, %{schemas: [], defs: definitions}, fn name, memo ->
      schema2 = function.(name)
      assembled = assemble(schema2, memo.defs, function)

      %{
        schemas: [schema2 | memo.schemas] ++ assembled.schemas,
        defs: Enum.uniq(memo.defs ++ assembled.defs)
      }
    end)
  end
end
