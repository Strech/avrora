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

  # NOTE: Modules below contain usage of some other modules which should be defined
  #       under the private client module, for instance, `Avrora.Config` could be
  #       defined as `MyClient.Config`. Hence they are listed together with some
  #       aliases.
  @modules ~w(
    encoder
    resolver
    avro_schema_store
    avro_decoder_options
    schema/encoder
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
    Resolver
    Schema.Encoder
    AvroDecoderOptions
    Codec.Plain
    Codec.SchemaRegistry
    Codec.ObjectContainerFile
    Storage.Registry
    Storage.File
  )

  defp personalize(definition, module: module) do
    definition = Regex.replace(~r/defmodule Avrora\./, definition, "defmodule ")

    ~r/alias Avrora\.([\w\.]+)(, as: [\w\.]+)?/
    |> Regex.scan(definition)
    |> Enum.reject(fn [_, modl | _] -> !Enum.member?(@aliases, modl) end)
    |> Enum.reduce(definition, fn [alis, modl | as], defn ->
      Regex.replace(~r/#{alis}(?=[[:cntrl:]])/, defn, "alias #{module}.#{modl}#{as}")
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
          @dialyzer {:no_match, [schemas_path: 0]}
          @moduledoc false

          @opts unquote(opts)
          @otp_app Keyword.get(@opts, :otp_app)

          def registry_url, do: get(@opts, :registry_url, nil)
          def registry_auth, do: get(@opts, :registry_auth, nil)
          def registry_user_agent, do: get(@opts, :registry_user_agent, "Avrora/#{version()} Elixir")
          def registry_ssl_cacerts, do: get(@opts, :registry_ssl_cacerts, nil)
          def registry_schemas_autoreg, do: get(@opts, :registry_schemas_autoreg, true)
          def convert_null_values, do: get(@opts, :convert_null_values, true)
          def convert_map_to_proplist, do: get(@opts, :convert_map_to_proplist, false)
          def names_cache_ttl, do: get(@opts, :names_cache_ttl, :infinity)
          def decoder_hook, do: get(@opts, :decoder_hook, fn _, _, data, fun -> fun.(data) end)
          def file_storage, do: unquote(:"Elixir.#{module}.Storage.File")
          def memory_storage, do: unquote(:"Elixir.#{module}.Storage.Memory")
          def registry_storage, do: unquote(:"Elixir.#{module}.Storage.Registry")
          def http_client, do: Avrora.HTTPClient
          def ets_lib, do: :"Elixir.#{unquote(module)}.AvroSchemaStore"

          defp version, do: Application.spec(:avrora, :vsn)

          if is_nil(@otp_app) do
            def self, do: __MODULE__
            def schemas_path, do: Path.expand(get(@opts, :schemas_path, "./priv/schemas"))
            def registry_ssl_cacert_path, do: nil

            defp get(opts, key, default), do: Keyword.get(opts, key, default)
          else
            def self, do: get(@opts, :config, __MODULE__)
            def schemas_path, do: Application.app_dir(@otp_app, get(@opts, :schemas_path, "./priv/schemas"))

            def registry_ssl_cacert_path do
              path = get(@opts, :registry_ssl_cacert_path, nil)

              if is_nil(path), do: nil, else: Path.expand(path)
            end

            defp get(opts, key, default) do
              app_opts = Application.get_env(@otp_app, unquote(:"Elixir.#{module}"), [])

              Keyword.get_lazy(app_opts, key, fn ->
                Keyword.get(opts, key, default)
              end)
            end
          end
        end
      end

    quote location: :keep do
      unquote(modules)
      unquote(config)

      use Supervisor

      defdelegate decode(payload), to: unquote(:"Elixir.#{module}.Encoder")
      defdelegate encode(payload, opts), to: unquote(:"Elixir.#{module}.Encoder")
      defdelegate decode(payload, opts), to: unquote(:"Elixir.#{module}.Encoder")
      defdelegate decode_plain(payload, opts), to: unquote(:"Elixir.#{module}.Encoder")
      defdelegate encode_plain(payload, opts), to: unquote(:"Elixir.#{module}.Encoder")
      defdelegate extract_schema(payload), to: unquote(:"Elixir.#{module}.Encoder")

      def start_link(opts \\ []), do: Supervisor.start_link(__MODULE__, opts, name: __MODULE__)

      @impl true
      def init(_state \\ []) do
        children = [
          unquote(:"Elixir.#{module}.AvroSchemaStore"),
          unquote(:"Elixir.#{module}.Storage.Memory")
        ]

        Supervisor.init(children, strategy: :one_for_all)
      end
    end
  end
end
