defmodule Support.AvroSchemaStore do
  @moduledoc """
  A host process and a wrapper for :avro_schema_store produced tables.
  Used only in tests

  See more: `Avrora.AvroSchemaStore`

  ## Examples:

    test "when we need test schema store creation" do
      {:ok, _} = start_link_supervised!(Support.AvroSchemaStore)
      stub(Avrora.ConfigMock, :ets_lib, fn -> Support.AvroSchemaStore end)

      IO.inspect(Support.AvroSchemaStore.count(), label: "AvroSchemaStore created")
      Support.AvroSchemaStore.new()
      IO.inspect(Support.AvroSchemaStore.count(), label: "AvroSchemaStore created")
    end
  """

  @prefix "avrora__test"

  use GenServer

  def start_link(opts \\ []) do
    {name_opts, _} = Keyword.split(opts, [:name])
    opts = Keyword.merge([name: __MODULE__], name_opts)

    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(_state \\ []), do: {:ok, []}

  @impl true
  def handle_call({:new}, _from, state),
    do: {:reply, :avro_schema_store.new(name: String.to_atom("#{@prefix}-#{rand()}")), state}

  def handle_call({:count}, _from, state),
    do: {:reply, Enum.count(:ets.all(), &is_test_store/1), state}

  @doc """
  Creates a new Erlang Term Store.

  ## Examples:

      iex> {:ok, _} = Support.AvroSchemaStore.start_link()
      iex> Support.AvroSchemaStore.new() |> :ets.info() |> Keyword.get(:size)
      0
  """
  @spec new() :: reference()
  def new, do: GenServer.call(__MODULE__, {:new})

  @doc """
  Returns a number of `:ets` tables matching the test prefix.

  ## Examples:

      iex> {:ok, _} = Support.AvroSchemaStore.start_link()
      iex> Support.AvroSchemaStore.count()
      0
      iex> Support.AvroSchemaStore.new()
      iex> Support.AvroSchemaStore.count()
      1
  """
  @spec count() :: non_neg_integer()
  def count, do: GenServer.call(__MODULE__, {:count})

  defp rand, do: :rand.uniform(1_000_000) + System.os_time()
  defp is_test_store(id), do: !is_reference(id) && Atom.to_string(id) =~ @prefix
end
