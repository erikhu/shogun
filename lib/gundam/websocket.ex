defmodule Gundam.Websocket do
  @moduledoc """
  Wrapper that use gun websocket client
  Please visit https://ninenines.eu/docs/en/gun/2.0/manual/gun/ for more info about the opts
  """

  @type headers() :: keyword()
  @type state() :: %{
    uri: URI.t(),
    headers: headers(),
    ws_opts: keyword(),
    open_opts: keyword()
  }
  @type reason() :: atom()
  @type message() :: binary()
  @type code() :: integer()

  @doc """
  trigger when the websocket client connects successfully
  """
  @callback on_connect(headers(), pid(), state()) :: state()

  @doc """
  trigger when the websocket client fails to connect successfully
  """
  @callback on_close(code(), reason(), pid(), state()) :: state()

  @doc """
  trigger when the websocket client has abruptly an error
  """
  @callback on_error(reason(), pid(), state()) :: state()

  @doc """
  trigger when the websocket client recieves an message from the server
  """
  @callback on_message(message(), pid(), state()) :: state()

  defmacro __using__(_opts) do
    quote do
      use GenServer

      @behaviour Gundam.Websocket

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

        open_opts = Keyword.take(opts, [
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

        transport = if uri.scheme == "wss", do: :tls , else: :tcp

        open_opts =
          open_opts
          |> Keyword.put_new(:protocols, [:http])
          |> Keyword.put_new(:transport, transport)
          |> Keyword.put_new(:tls_opts, [verify_type: :verify_peer, cacerts: :public_key.cacerts_get()])
          |> Keyword.put_new(:http_opts,  %{version: :"HTTP/1.1"})
          |> Keyword.put_new(:ws_opts,  %{keepalive: :infinity})

        [{:open_opts, Map.new(open_opts)} | args]
      end

      # ws_opts() https://ninenines.eu/docs/en/gun/2.0/manual/gun/
      defp add_ws_opts(args, opts) do
        ws_opts = Keyword.take(opts, [
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
         %{uri: args[:uri], headers: args[:headers], ws_opts: args[:ws_opts], open_opts: args[:open_opts], connected: false},
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

      def send_message(ws_pid, message) do
        GenServer.cast(ws_pid, {:send_message, message})
      end

      def state(ws_pid) do
        GenServer.call(ws_pid, :state)
      end

      @impl GenServer
      def handle_cast({:send_message, _whatever}, %{connected: false} = state) do
        {:noreply, {:error, :not_connected}, state}
      end

      def handle_cast({:send_message, :ping}, %{conn_pid: conn_pid, ws_ref: ws_ref} = state) do
        :ok = :gun.ws_send(conn_pid, ws_ref, :ping)
        {:noreply, :pong, state}
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
      def handle_info({:gun_ws, pid, _ref, message}, state) do
        state = on_message(message, pid, state)
        {:noreply, state}
      end

      @doc """
      When the upgrade succeeds, a gun_upgrade message is sent.
      """
      @impl GenServer
      def handle_info({:gun_upgrade, pid, ref, _code, headers}, state) do
        state = on_connect(headers, pid, state)
        {:noreply, Map.put(state, :connected, true)}
      end

      @doc """
      If the server does not understand Websocket or refused the upgrade, a gun_response message is sent.
      """
      @impl GenServer
      def handle_info({:gun_response, pid, a, b, status, _headers}, state) do
        state = on_close(status, status, pid, state)
        {:stop, :normal, Map.put(state, :connected, false)}
      end

      @doc """
      If Gun couldn't perform the upgrade due to an error (for example attempting to upgrade
      to Websocket on an HTTP/1.0 connection) then a gun_error message is sent.
      """
      @impl GenServer
      def handle_info({:gun_error, pid, _ref, reason}, state) do
        state = on_error(reason, pid, state)
        {:stop, :normal, Map.put(state, :connected, false)}
      end

      @impl GenServer
      def handle_info({:gun_up, _pid, protocol}, %{conn_pid: conn_pid, uri: uri, headers: headers, ws_opts: ws_opts} = state) do
        ws_ref = :gun.ws_upgrade(conn_pid, "#{uri.path}?#{uri.query}" , headers, ws_opts)
        state = Map.put(state, :ws_ref, ws_ref)

        {:noreply, state}
      end

      @impl Gundam.Websocket
      def on_connect(_headers, _pid, state), do: state

      @impl Gundam.Websocket
      def on_close(_code, _reason, _pid, state), do: state

      @impl Gundam.Websocket
      def on_error(_reason, _pid, state), do: state

      @impl Gundam.Websocket
      def on_message(_message, _pid, state), do: state
    end
  end
end
