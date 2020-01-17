defmodule Avrora.ETSTest do
  use ExUnit.Case, async: true
  doctest Avrora.ETS

  alias Avrora.ETS

  setup do
    pid = start_supervised!({ETS, name: :test_ets})

    %{ets: pid}
  end

  describe "new/2" do
    test "when table was created", %{ets: pid} do
      table_size =
        pid
        |> ETS.new()
        |> :ets.info()
        |> Keyword.get(:size)

      assert table_size == 0
    end
  end
end
