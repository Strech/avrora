defmodule Avrora.AvroSchemaStoreTest do
  use ExUnit.Case, async: true
  doctest Avrora.AvroSchemaStore

  alias Avrora.AvroSchemaStore

  setup do
    pid = start_supervised!({AvroSchemaStore, name: :test_ets})

    %{ets: pid}
  end

  describe "new/2" do
    test "when table was created", %{ets: pid} do
      table_size =
        pid
        |> AvroSchemaStore.new()
        |> :ets.info()
        |> Keyword.get(:size)

      assert table_size == 0
    end
  end
end
