defmodule Avrora.Storage.Memory do
  @moduledoc """
  Fast in-memory storage of schemas with access by global id or full name.
  """

  use GenServer
  alias Avrora.{Schema, Storage}

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
  def handle_cast({:expire, key, ttl}, state) do
    pid = self()

    # NOTE: Maybe it's better to replace it with a combination of
    #       Process.send_after/4 + GenServer.handle_info/2
    {:ok, _} =
      Task.start(fn ->
        Process.sleep(ttl)
        __MODULE__.delete(pid, key)
      end)

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

  @impl true
  def handle_call({:delete, key}, _from, state) do
    {:ok, table} = Keyword.fetch(state, :table)
    {:reply, :ets.delete(table, key), state}
  end

  @doc """
  Retrieve a value by a given key.

  ## Examples
      iex> _ = Avrora.Storage.Memory.start_link()
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
  @spec get(pid() | atom(), Storage.schema_id()) :: {:ok, nil | Schema.t()} | {:error, term()}
  def get(pid, key), do: {:ok, GenServer.call(pid, {:get, key})}

  @doc """
  Stores a value with a given key. If the value is already exists it will be replaced.

  ## Examples
      iex> _ = Avrora.Storage.Memory.start_link()
      iex> avro = %Avrora.Schema{id: nil, schema: [], raw_schema: "{}"}
      iex> Avrora.Storage.Memory.put("my-key", avro)
      {:ok, %Avrora.Schema{id: nil, schema: [], raw_schema: "{}"}}
  """
  @impl true
  def put(key, value), do: put(__MODULE__, key, value)

  @doc false
  @spec put(pid() | atom(), Storage.schema_id(), Schema.t()) ::
          {:ok, Avrora.Schema.t()} | {:error, term()}
  def put(pid, key, value), do: {GenServer.cast(pid, {:put, key, value}), value}

  @doc """
  Deletes a key from the storage. Works no matter the key exists or not.

  ## Examples
      iex> _ = Avrora.Storage.Memory.start_link()
      iex> avro = %Avrora.Schema{id: nil, schema: [], raw_schema: "{}"}
      iex> Avrora.Storage.Memory.put("my-key", avro)
      {:ok, %Avrora.Schema{id: nil, schema: [], raw_schema: "{}"}}
      iex> Avrora.Storage.Memory.get("my-key")
      {:ok, %Avrora.Schema{id: nil, schema: [], raw_schema: "{}"}}
      iex> Avrora.Storage.Memory.delete("my-key")
      {:ok, true}
      iex> Avrora.Storage.Memory.get("my-key")
      {:ok, nil}
  """
  @spec delete(Storage.schema_id()) :: {:ok, boolean()} | {:error, term()}
  def delete(key), do: delete(__MODULE__, key)

  @doc false
  @spec delete(pid() | atom(), Storage.schema_id()) :: {:ok, boolean()} | {:error, term()}
  def delete(pid, key), do: {:ok, GenServer.call(pid, {:delete, key})}

  @doc """
  Expires a key in the storage after its TTL is over. Works no matter the key exists or not.
  TTL is measured in millisecods.

  ## Examples
      iex> _ = Avrora.Storage.Memory.start_link()
      iex> avro = %Avrora.Schema{id: nil, schema: [], raw_schema: "{}"}
      iex> Avrora.Storage.Memory.put("my-key", avro)
      {:ok, %Avrora.Schema{id: nil, schema: [], raw_schema: "{}"}}
      iex> {:ok, _} = Avrora.Storage.Memory.expire("my-key", 100)
      iex> Avrora.Storage.Memory.get("my-key")
      {:ok, %Avrora.Schema{id: nil, schema: [], raw_schema: "{}"}}
      iex> Process.sleep(100)
      iex> Avrora.Storage.Memory.get("my-key")
      {:ok, nil}
  """
  @spec expire(Storage.schema_id(), integer()) :: {:ok, integer()} | {:error, term()}
  def expire(key, ttl), do: expire(__MODULE__, key, ttl)

  @doc false
  @spec expire(pid() | atom(), Storage.schema_id(), integer()) ::
          {:ok, integer()} | {:error, term()}
  def expire(pid, key, ttl), do: {GenServer.cast(pid, {:expire, key, ttl}), timestamp(ttl)}

  defp timestamp(shift), do: trunc(System.system_time(:second) + shift / 1_000)
end
