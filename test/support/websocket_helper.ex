defmodule Gundam.WebsocketHelper do
  # took from plug cowboy project websocket_handler_test.exs

  defmodule WebSocketHandler do
    @behaviour :cowboy_websocket

    # We never actually call this; it's just here to quell compiler warnings
    @impl true
    def init(req, state), do: {:cowboy_websocket, req, state}

    @impl true
    def websocket_init(_opts), do: {:ok, :init}

    def websocket_handle(:ping, state) do
      {:reply, :pong, state}
    end
    
    @impl true
    def websocket_handle({:text, "state"}, state), do: {:reply,[{:text, inspect(state)}], state}

    def websocket_handle({:text, msg}, state),
      do: {:reply, [{:text, msg}], state}

    @impl true
    def websocket_info(msg, state) do
      IO.inspect(msg, label: "[WebsocketHelper] Unhandle: ")
      {:ok, state}
    end
  end

  @behaviour Plug

  @impl Plug
  def init(arg), do: arg

  @impl Plug
  def call(conn, _opts) do
    Plug.Conn.upgrade_adapter(conn, :websocket, {WebSocketHandler, [], %{idle_timeout: 1000}})
  end

  def ws_server_info(:https) do
    :ranch.info(__MODULE__.HTTPS)
  end

  def ws_server_info(_scheme) do
    :ranch.info(__MODULE__.HTTP)
  end
end

defmodule Gundam.WebsocketTest do
  use Gundam.Websocket
end
