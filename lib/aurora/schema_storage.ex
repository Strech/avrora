defmodule Avrora.SchemaStorage do
  @moduledoc """
  Fast in-memory storage of schemas with access by global id or full name.
  """

  use GenServer

  @ets_opts [
    :private,
    :set,
    :compressed,
    {:read_concurrency, true},
    {:write_concurrency, true}
  ]

  def start_link(opts \\ []) do
    opts =
      with {name_opts, _} <- Keyword.split(opts, [:name]),
           do: Keyword.merge([name: __MODULE__], name_opts)

    GenServer.start_link(__MODULE__, [], opts)
  end

  @impl true
  def init(_state \\ []) do
    {:ok, [table: :ets.new(nil, @ets_opts)]}
  end

  @impl true
  def handle_cast({:put, key, value}, state) do
    {:ok, table} = Keyword.fetch(state, :table)

    true = :ets.insert(table, {key, value})
    {:noreply, state}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    {:ok, table} = Keyword.fetch(state, :table)

    case :ets.lookup(table, key) do
      [{_, value}] -> {:reply, value, state}
      _ -> {:reply, nil, state}
    end
  end

  @doc """
  Store a value with a given key. If the value is already exists it will be replaced.

  ## Examples
      iex> {:ok, _} = Avrora.SchemaStorage.start_link()
      iex> Avrora.SchemaStorage.put("my-key", %{"hello" => "world"})
      :ok
  """
  @spec put(String.t() | integer(), any()) :: :ok
  def put(key, value), do: put(__MODULE__, key, value)

  @doc false
  @spec put(pid() | atom(), String.t() | integer(), any()) :: :ok
  def put(pid, key, value), do: GenServer.cast(pid, {:put, key, value})

  @doc """
  Retrieve a value by a given key.

  ## Examples
      iex> {:ok, _} = Avrora.SchemaStorage.start_link()
      iex> Avrora.SchemaStorage.put("my-key", %{"hello" => "world"})
      :ok
      iex> Avrora.SchemaStorage.get("my-key")
      %{"hello" => "world"}
      iex> Avrora.SchemaStorage.get("unknown-key")
      nil
  """
  @spec get(String.t() | integer()) :: nil | any()
  def get(key), do: get(__MODULE__, key)

  @doc false
  @spec get(pid() | atom(), String.t() | integer()) :: nil | any()
  def get(pid, key), do: GenServer.call(pid, {:get, key})
end
