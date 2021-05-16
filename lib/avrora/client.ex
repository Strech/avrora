defmodule Avrora.Client do
  @moduledoc """
  Generates client module with isolated memory storage.

  ## Examples

       defmodule MyClient do
         use Avrora.Client,
           schemas_path: Path.expand("./priv/schemas"),
           registry_url: "https://registry.io"
       end

  It will expose `Avrora.Encoder` module functions and make `MyClient` module
  identical to `Avrora` module, but isolated from it.

  To start using `MyClient` follow the [Start cache process](README.md#start-cache-process),
  add it to your supervision tree

       children = [
         MyClient
       ]

       Supervisor.start_link(children, strategy: :one_for_one)

  or start the process manually

       {:ok, pid} = MyClient.start_link()
  """

  @modules ~w(
    schema
    encoder
    resolver
    avro_schema_store
    avro_decoder_options
    codec/plain
    codec/schema_registry
    codec/object_container_file
    storage/file
    storage/memory
    storage/registry
    utils/registrar
  )

  @aliases ~w(
    Codec
    Config
    Schema
    Resolver
    AvroDecoderOptions
    Codec.Plain
    Codec.SchemaRegistry
    Codec.ObjectContainerFile
    Storage.Registry
    Storage.File
  )

  defp personalize(definition, module: module) do
    definition = Regex.replace(~r/defmodule Avrora\./, definition, "defmodule ")

    ~r/alias Avrora\.(.*)/
    |> Regex.scan(definition)
    |> Enum.reject(fn [_, m] -> !Enum.member?(@aliases, m) end)
    |> Enum.reduce(definition, fn [als, mdl], dfn ->
      Regex.replace(~r/#{als}(?=[[:cntrl:]])/, dfn, "alias #{module}.#{mdl}")
    end)
  end

  defp generate!(definition, file: file) do
    case Code.string_to_quoted(definition, file: file) do
      {:ok, quoted} ->
        quoted

      {:error, {line, error, token}} ->
        raise "error #{error} on line #{line} caused by #{inspect(token)}"
    end
  end

  defmacro __using__(opts) do
    module = __CALLER__.module |> Module.split() |> Enum.join(".")

    modules =
      @modules
      |> Enum.map(fn name ->
        file = Path.expand("./#{name}.ex", __DIR__)

        file
        |> File.read!()
        |> personalize(module: module)
        |> generate!(file: file)
      end)

    config =
      quote do
        defmodule Config do
          @moduledoc false
          @opts unquote(opts)

          import Keyword, only: [get: 3]

          def schemas_path, do: get(@opts, :schemas_path, Path.expand("./priv/schemas"))
          def registry_url, do: get(@opts, :registry_url, nil)
          def registry_auth, do: get(@opts, :registry_url, nil)
          def registry_schemas_autoreg, do: get(@opts, :registry_schemas_autoreg, true)
          def convert_null_values, do: get(@opts, :convert_null_values, true)
          def convert_map_to_proplist, do: get(@opts, :convert_map_to_proplist, false)
          def names_cache_ttl, do: get(@opts, :names_cache_ttl, :infinity)
          def file_storage, do: :"Elixir.#{unquote(module)}.Storage.File"
          def memory_storage, do: :"Elixir.#{unquote(module)}.Storage.Memory"
          def registry_storage, do: :"Elixir.#{unquote(module)}.Storage.Registry"
          def http_client, do: Avrora.HTTPClient
          def ets_lib, do: :"Elixir.#{unquote(module)}.AvroSchemaStore"
          def self, do: __MODULE__
        end
      end

    quote location: :keep do
      unquote(modules)
      unquote(config)

      use Supervisor

      defdelegate decode(payload), to: :"Elixir.#{unquote(module)}.Encoder"
      defdelegate encode(payload, opts), to: :"Elixir.#{unquote(module)}.Encoder"
      defdelegate decode(payload, opts), to: :"Elixir.#{unquote(module)}.Encoder"
      defdelegate decode_plain(payload, opts), to: :"Elixir.#{unquote(module)}.Encoder"
      defdelegate encode_plain(payload, opts), to: :"Elixir.#{unquote(module)}.Encoder"
      defdelegate extract_schema(payload), to: :"Elixir.#{unquote(module)}.Encoder"

      def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

      @impl true
      def init(_state \\ []) do
        children = [
          :"Elixir.#{unquote(module)}.AvroSchemaStore",
          :"Elixir.#{unquote(module)}.Storage.Memory"
        ]

        Supervisor.init(children, strategy: :one_for_all)
      end
    end
  end
end
