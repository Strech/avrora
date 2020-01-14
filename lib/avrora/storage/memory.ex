defmodule Avrora.Storage.Memory do
  @moduledoc """
  `Avora.Storage` behavior implementation which uses memory (ETS).

  Schemas can be accessed by integer id or full name.
  """

  use GenServer
  alias Avrora.{Schema, Storage}

  @behaviour Storage
  @behaviour Storage.Transient

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

  @impl true
  def handle_call({:flush}, _from, state) do
    {:ok, table} = Keyword.fetch(state, :table)
    {:reply, :ets.delete_all_objects(table), state}
  end

  @doc """
  Get schema by key.

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
  Store schema by key. If value already exists it will be replaced.

  ## Examples
      iex> _ = Avrora.Storage.Memory.start_link()
      iex> schema = %Avrora.Schema{id: nil, json: "{}"}
      iex> Avrora.Storage.Memory.put("my-key", schema)
      {:ok, %Avrora.Schema{id: nil, json: "{}"}}
  """
  @impl true
  def put(key, value), do: put(__MODULE__, key, value)

  @doc false
  @spec put(pid() | atom(), Storage.schema_id(), Schema.t()) ::
          {:ok, Avrora.Schema.t()} | {:error, term()}
  def put(pid, key, value), do: {GenServer.cast(pid, {:put, key, value}), value}

  @doc """
  Delete data from storage by key. Always succeeds, whether or not the key exists.

  ## Examples
      iex> _ = Avrora.Storage.Memory.start_link()
      iex> schema = %Avrora.Schema{id: nil, json: "{}"}
      iex> Avrora.Storage.Memory.put("my-key", schema)
      {:ok, %Avrora.Schema{id: nil, json: "{}"}}
      iex> Avrora.Storage.Memory.get("my-key")
      {:ok, %Avrora.Schema{id: nil, json: "{}"}}
      iex> Avrora.Storage.Memory.delete("my-key")
      {:ok, true}
      iex> Avrora.Storage.Memory.get("my-key")
      {:ok, nil}
  """
  @impl true
  def delete(key), do: delete(__MODULE__, key)

  @doc false
  @spec delete(pid() | atom(), Storage.schema_id()) :: {:ok, boolean()} | {:error, term()}
  def delete(pid, key), do: {:ok, GenServer.call(pid, {:delete, key})}

  @doc """
  Tell storage module to delete data after TTL (time to live) expires. Works whether or not the key exists.
  TTL is in milliseconds.

  ## Examples
      iex> _ = Avrora.Storage.Memory.start_link()
      iex> schema = %Avrora.Schema{id: nil, json: "{}"}
      iex> Avrora.Storage.Memory.put("my-key", schema)
      {:ok, %Avrora.Schema{id: nil, json: "{}"}}
      iex> {:ok, _} = Avrora.Storage.Memory.expire("my-key", 100)
      iex> Avrora.Storage.Memory.get("my-key")
      {:ok, %Avrora.Schema{id: nil, json: "{}"}}
      iex> Process.sleep(200)
      iex> Avrora.Storage.Memory.get("my-key")
      {:ok, nil}
  """
  @impl true
  def expire(key, ttl), do: expire(__MODULE__, key, ttl)

  @doc false
  def expire(_pid, _key, :infinity), do: {:ok, :infinity}

  @doc false
  @spec expire(pid() | atom(), Storage.schema_id(), timeout()) ::
          {:ok, Storage.Transient.timestamp()} | {:error, term()}
  def expire(pid, key, ttl), do: {GenServer.cast(pid, {:expire, key, ttl}), timestamp(ttl)}

  @doc """
  Complete clean up of the storage. Useful for testing.

  ## Examples
      iex> _ = Avrora.Storage.Memory.start_link()
      iex> schema = %Avrora.Schema{id: nil, json: "{}"}
      iex> Avrora.Storage.Memory.put("my-key", schema)
      {:ok, %Avrora.Schema{id: nil, json: "{}"}}
      iex> {:ok, _} = Avrora.Storage.Memory.flush()
      iex> Avrora.Storage.Memory.get("my-key")
      {:ok, nil}
  """
  @impl true
  def flush, do: flush(__MODULE__)

  @doc false
  @spec flush(pid() | atom()) :: {:ok, boolean()} | {:error, term()}
  def flush(pid), do: {:ok, GenServer.call(pid, {:flush})}

  defp timestamp(shift), do: trunc(System.system_time(:second) + shift / 1_000)
end
