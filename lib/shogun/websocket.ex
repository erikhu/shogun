defmodule Shogun.Websocket do
  @moduledoc """
  Wrapper that uses gun websocket client

  ## Usage
  ```elixir
  defmodule MyWebsocket do
    use Shogun.Websocket
  end

  {:ok, pid} = MyWebsocket.start_link(url: "ws://localhost/websocket")
  ```

  ## Usage of callbacks
  ```elixir
  defmodule MyWebsocket do
    use Shogun.Websocket

    @impl Shogun.Websocket
    def on_connect(_headers, state) do
      # Doing something awesome ...
      state
    end
  end
  ```

  ## Opts

  **url:** url to websocket server (ws or wss), for instance `ws://websocket_server/`. **required**

  **connect_timeout:** Connection timeout. default :infinity

  **cookie_store:** The cookie store that Gun will use for this connection. When configured, Gun will query the store for cookies and include them in the request headers; and add cookies found in response headers to the store.

    By default no cookie store will be used.

  **domain_lookup_timeout:** Domain lookup timeout. default :infinity

  **http_opts:** Options specific to the HTTP protocol.

  **retry:** Number of times Gun will try to reconnect on failure before giving up.

  **retry_fun:** A fun that will be called before every reconnect attempt. It receives the current number of retries left and the Gun options. It returns the next number of retries left and the timeout to apply before reconnecting.

  The default fun will remove one to the number of retries and set the timeout to the retry_timeout value.

  The fun must be defined as follow:

  ```elixir
  fn(non_neg_integer(), opts()) -> %{
    retries => non_neg_integer(),
    timeout => pos_integer()
  } end
  ```

  The fun will never be called when the retry option is set to 0. When this function returns 0 in the retries value, Gun will do one last reconnect attempt before giving up.

  **retry_timeout:** Time between retries in milliseconds. default 5000

  **supervise:** Whether the Gun process should be started under the gun_sup supervisor. Set to false to use your own supervisor. default true

  **tcp_opts:** TCP options used when establishing the connection. By default Gun enables send timeouts with the options [{send_timeout, 15000}, {send_timeout_close, true}].

  **tls_handshake_timeout:** TLS handshake timeout. default :infinity

  **tls_opts:** TLS options used for the TLS handshake after the connection has been established, when the transport is set to tls. default []

  **trace:** Whether to enable dbg tracing of the connection process. Should only be used during debugging. default false

  **transport:** Whether to use TLS or plain TCP. The default varies depending on the port used. Port 443 defaults to tls. All other ports default to tcp.

  **ws_opts:** Options specific to the Websocket protocol.

  Please visit https://ninenines.eu/docs/en/gun/2.0/manual/gun/ for more info about the opts

  """

  @type headers() :: keyword()
  @type state() :: %{
          uri: URI.t(),
          headers: headers(),
          ws_opts: keyword(),
          open_opts: keyword(),
          internal_state: map()
        }
  @type reason() :: atom()
  @type message() :: binary()
  @type code() :: integer()

  @doc """
  trigger when the websocket client connects successfully
  """
  @callback on_connect(headers(), state()) :: state()

  @doc """
  trigger when the connection is lost (gun will try to connect again and upgrade to ws)
  """
  @callback on_disconnect(reason(), state()) :: state()

  @doc """
  trigger when the websocket client fails to connect successfully
  """
  @callback on_close(code(), state()) :: state()

  @doc """
  trigger when the websocket client has abruptly an error
  """
  @callback on_error(reason(), state()) :: state()

  @doc """
  trigger when the websocket client recieves an message from the server
  """
  @callback on_message(message(), state()) :: state()

  defmacro __using__(_opts) do
    quote do
      use GenServer

      @behaviour Shogun.Websocket

      def start_link(opts) do
        uri = URI.parse(opts[:url])

        args =
          [headers: opts[:headers] || [], uri: uri]
          |> add_open_opts(opts)
          |> add_ws_opts(opts)

        GenServer.start_link(__MODULE__, args, opts)
      end

      # opts() https://ninenines.eu/docs/en/gun/2.0/manual/gun/
      defp add_open_opts(args, opts) do
        uri = args[:uri]

        open_opts =
          Keyword.take(opts, [
            :connect_timeout,
            :cookie_store,
            :domain_lookup_timeout,
            :http_opts,
            :http2_opts,
            :protocols,
            :retry,
            :retry_fun,
            :retry_timeout,
            :supervise,
            :tcp_opts,
            :tls_handshake_timeout,
            :tls_opts,
            :trace,
            :transport,
            :ws_opts
          ])

        transport = if uri.scheme == "wss", do: :tls, else: :tcp

        open_opts =
          open_opts
          |> Keyword.put_new(:protocols, [:http])
          |> Keyword.put_new(:transport, transport)
          |> Keyword.put_new(:tls_opts, :tls_certificate_check.options(uri.host))
          |> Keyword.put_new(:http_opts, %{version: :"HTTP/1.1"})
          |> Keyword.put_new(:ws_opts, %{keepalive: :infinity})

        [{:open_opts, Map.new(open_opts)} | args]
      end

      # ws_opts() https://ninenines.eu/docs/en/gun/2.0/manual/gun/
      defp add_ws_opts(args, opts) do
        ws_opts =
          Keyword.take(opts, [
            :closing_timeout,
            :compress,
            :default_protocol,
            :flow,
            :keepalive,
            :protocols,
            :silence_pings
          ])

        ws_opts =
          ws_opts
          |> Keyword.put_new(:keepalive, :infinity)

        [{:ws_opts, Map.new(ws_opts)} | args]
      end

      @impl GenServer
      def init(args) do
        {
          :ok,
          %{
            uri: args[:uri],
            headers: args[:headers],
            ws_opts: args[:ws_opts],
            open_opts: args[:open_opts],
            connected: false,
            internal_state: %{}
          },
          {:continue, :connect}
        }
      end

      @impl GenServer
      def handle_continue(
            :connect,
            %{uri: uri, headers: headers, ws_opts: ws_opts, open_opts: open_opts} = state
          ) do
        with {:ok, conn_pid} <- :gun.open(String.to_charlist(uri.host), uri.port, open_opts) do
          state = Map.put(state, :conn_pid, conn_pid)

          {:noreply, state}
        end
      end

      def ping(ws_pid) do
        GenServer.cast(ws_pid, {:send_message, :ping})
      end

      def send_message(ws_pid, message) when is_binary(message) do
        GenServer.cast(ws_pid, {:send_message, message})
      end

      def state(ws_pid) do
        GenServer.call(ws_pid, :state)
      end

      @impl GenServer
      def handle_cast({:send_message, _message}, %{connected: false} = state) do
        {:noreply, state}
      end

      def handle_cast({:send_message, :ping}, %{conn_pid: conn_pid, ws_ref: ws_ref} = state) do
        :ok = :gun.ws_send(conn_pid, ws_ref, :ping)
        {:noreply, state}
      end

      @impl GenServer
      def handle_cast({:send_message, message}, %{conn_pid: conn_pid, ws_ref: ws_ref} = state) do
        :ok = :gun.ws_send(conn_pid, ws_ref, [{:text, message}])
        {:noreply, state}
      end

      @impl GenServer
      def handle_call(:state, _caller, state) do
        {:reply, state, state}
      end

      @doc """
      Gun sends an Erlang message to the owner process for every Websocket message it receives.
      """
      @impl GenServer
      def handle_info({:gun_ws, _pid, _ref, message}, %{internal_state: internal_state} = state) do
        internal_state = on_message(message, internal_state)
        {:noreply, Map.put(state, :internal_state, internal_state)}
      end

      @doc """
      When the upgrade succeeds, a gun_upgrade message is sent.
      """
      @impl GenServer
      def handle_info(
            {:gun_upgrade, _pid, ref, _code, headers},
            %{internal_state: internal_state} = state
          ) do
        internal_state = on_connect(headers, internal_state)

        state =
          state
          |> Map.put(:connected, true)
          |> Map.put(:internal_state, internal_state)

        {:noreply, state}
      end

      @doc """
      If the server does not understand Websocket or refused the upgrade, a gun_response message is sent.
      """
      @impl GenServer
      def handle_info(
            {:gun_response, _conn_pid, _stream_ref, _is_fin, status, _headers},
            %{internal_state: internal_state} = state
          ) do
        internal_state = on_close(status, internal_state)

        state =
          state
          |> Map.put(:connected, false)
          |> Map.put(:internal_state, internal_state)

        {:stop, :normal, state}
      end

      @doc """
      If Gun couldn't perform the upgrade due to an error (for example attempting to upgrade
      to Websocket on an HTTP/1.0 connection) then a gun_error message is sent.
      """
      @impl GenServer
      def handle_info(
            {:gun_error, _pid, _stream_ref, reason},
            %{internal_state: internal_state} = state
          ) do
        state = on_error(reason, internal_state)

        state =
          state
          |> Map.put(:connected, false)
          |> Map.put(:internal_state, internal_state)

        {:stop, :normal, state}
      end

      @impl GenServer
      def handle_info(
            {:gun_up, pid, protocol},
            %{conn_pid: conn_pid, uri: uri, headers: headers, ws_opts: ws_opts} = state
          ) do
        ws_ref = :gun.ws_upgrade(conn_pid, "#{uri.path}?#{uri.query}", headers, ws_opts)
        state = Map.put(state, :ws_ref, ws_ref)

        {:noreply, state}
      end

      @impl GenServer
      def handle_info(
            {:gun_down, _pid, _protocol, reason, _killed_streams},
            %{internal_state: internal_state} = state
          ) do
        internal_state = on_disconnect(reason, internal_state)

        state =
          state
          |> Map.put(:connected, false)
          |> Map.put(:internal_state, internal_state)

        {:noreply, state}
      end

      def on_close(_code, state), do: state
      def on_connect(_headers, state), do: state
      def on_disconnect(_reason, state), do: state
      def on_error(_reason, state), do: state
      def on_message(_message, state), do: state

      defoverridable on_close: 2
      defoverridable on_connect: 2
      defoverridable on_disconnect: 2
      defoverridable on_error: 2
      defoverridable on_message: 2
    end
  end
end
