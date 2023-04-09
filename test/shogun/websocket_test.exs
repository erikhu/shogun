defmodule Shogun.WebsocketTest do
  use ExUnit.Case, async: true

  alias Shogun.Websocket.GunTest
  alias Shogun.WebsocketClientTest

  setup _context do
    Application.put_env(:shogun, Shogun.Websocket, client: Shogun.Websocket.GunTest)
    {:ok, ws_pid} = start_supervised({WebsocketClientTest, url: "test"})
    on_exit(fn -> Application.delete_env(:shogun, Shogun.Websocket) end)
    [ws_pid: ws_pid]
  end

  test "test gun_test", %{ws_pid: ws_pid} do
    GunTest.receive_message(ws_pid, "test")
    assert :sys.get_state(ws_pid).internal_state.message == {:text, "test"}
  end
end
