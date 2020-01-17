defmodule Avrora.ETS do
  @moduledoc """
  A host process for ets tables. It is used only to create new
  tables.

  This process will be in the save supervision tree as `Avrora.Storage.Memory`
  with a stragety `one for all`.

  See more:
    - https://github.com/Strech/avrora/issues/21
    - https://elixirforum.com/t/do-we-need-a-process-for-ets-tables/22705
  """

  use GenServer

  def start_link(opts \\ []) do
    {name_opts, _} = Keyword.split(opts, [:name])
    opts = Keyword.merge([name: __MODULE__], name_opts)

    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(_state \\ []), do: {:ok, []}

  @impl true
  def handle_call({:new}, _from, state) do
    table = :ets.new(__MODULE__, [:public, {:read_concurrency, true}])
    {:reply, table, state}
  end

  @doc """
  Creates a new Erlang Term Store.

  ## Examples:

      iex> {:ok, _} = Avrora.ETS.start_link()
      iex> Avrora.ETS.new() |> :ets.info() |> Keyword.get(:size)
      0
  """
  def new, do: new(__MODULE__)

  @doc false
  @spec new(pid() | atom()) :: reference()
  def new(pid), do: GenServer.call(pid, {:new})
end
