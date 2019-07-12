defmodule Avrora.Storage.Memory do
  @moduledoc """
  Fast in-memory storage of schemas with access by global id or full name.
  """

  use GenServer

  @behaviour Avrora.Storage
  @ets_opts [
    :private,
    :set,
    :compressed,
    {:read_concurrency, true},
    {:write_concurrency, true}
  ]

  def start_link(opts \\ []) do
    {name_opts, _} = Keyword.split(opts, [:name])
    opts = Keyword.merge([name: __MODULE__], name_opts)

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
  Retrieve a value by a given key.

  ## Examples
      iex> {:ok, _} = Avrora.Storage.Memory.start_link()
      iex> Avrora.Storage.Memory.put("my-key", %{"hello" => "world"})
      {:ok, %{"hello" => "world"}}
      iex> Avrora.Storage.Memory.get("my-key")
      {:ok, %{"hello" => "world"}}
      iex> Avrora.Storage.Memory.get("unknown-key")
      {:ok, nil}
  """
  @impl true
  def get(key), do: get(__MODULE__, key)

  @doc false
  @spec get(pid() | atom(), String.t() | integer()) ::
          {:ok, nil | Avrora.Schema.t()} | {:error, term()}
  def get(pid, key), do: {:ok, GenServer.call(pid, {:get, key})}

  @doc """
  Stores a value with a given key. If the value is already exists it will be replaced.

  ## Examples
      iex> {:ok, _} = Avrora.Storage.Memory.start_link()
      iex> avro = %Avrora.Schema{id: nil, schema: [], raw_schema: "{}"}
      iex> Avrora.Storage.Memory.put("my-key", avro)
      {:ok, %Avrora.Schema{id: nil, schema: [], raw_schema: "{}"}}
  """
  @impl true
  def put(key, value), do: put(__MODULE__, key, value)

  @doc false
  @spec put(pid() | atom(), String.t() | integer(), Avrora.Schema.t()) ::
          {:ok, Avrora.Schema.t()} | {:error, term()}
  def put(pid, key, value), do: {GenServer.cast(pid, {:put, key, value}), value}
end
