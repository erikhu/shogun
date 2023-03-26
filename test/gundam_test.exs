defmodule GundamTest do
  use ExUnit.Case, async: true

  alias Gundam.WebsocketHelper
  alias Gundam.WebsocketTest

  @protocol_options [
    idle_timeout: 1000,
    request_timeout: 1000
  ]

  setup _context do
    {:ok, ws_server_pid} = start_supervised({
      Plug.Cowboy,
      scheme: :http,
      plug: WebsocketHelper,
      options: [port: 0, protocol_options: @protocol_options]
        })

    ws_server_info = WebsocketHelper.ws_server_info()
    [ws_server_pid: ws_server_pid, ws_server_info: ws_server_info]
  end

  test "unsecure connect to websocket server", %{ws_server_info: ws_server_info} do
    {:ok, ws_pid} = start_supervised({WebsocketTest, [url: "ws://localhost:#{ws_server_info[:port]}/"]})
    :ok = WebsocketTest.subscribe(ws_pid)
    assert_received :ws_on_connect
  end

  # test "secure connect to websocket server", %{ws_server_info: ws_server_info} do
  #   {:ok, ws_pid} = start_supervised({WebsocketTest, [url: "wss://localhost:#{ws_server_info[:port]}/"]})
  #   :ok = WebsocketTest.subscribe()
  #   assert_received :ws_on_connect
  # end


  # test "error connecting to wrong server" do
  #   assert {:error, :closed} = Gundam.websocket("ws://test/invalid")
  # end

  # test "connect to websocket server by application child", %{ws_server_info: ws_server_info} do
  #   assert {:ok, ws_pid} = Gundam.Websocket.start_link(url: ws_server_info[:url])
  #   assert_ping_pong(ws_pid)
  # end

  # test "child_spec", %{ws_server_inf: ws_server_info} do
  #   spec = {Gundam.WebsocketTest, [url: ws_server_info[:url]]}

  #   assert Supervisor.child_spec(spec) == %{
  #            id: {Gundam.WebsocketTest, 1},
  #            start: {Gundam.WebsocketTest, :start_link, [[url: ws_server_info[:url]]]}
  #          }
  # end
end
