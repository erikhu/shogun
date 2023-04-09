defmodule Shogun.Websocket.GunTest do
  @behaviour Shogun.Websocket.Client

  @moduledoc """
  GunTest can help to test your implementation of Shogun.Websocket
  Follow the steps to test it out

  First step:

  set the client for the websocket in `config/test.exs`

  ```elixir
  config :shogun, Shogun.Websocket,
    client: Shogun.Websocket.GunTest
  ```

  Second step:

  now on your test, you can control the messages that your websocket received.

  ```elixir
  defmodule MyApp.Websocket do
    use ExUnit.Case, async: true

    alias Shogun.Websocket.GunTest

    setup _context do
      {:ok, ws_pid} = start_supervised({MyApp.Websocket, url: "test"})
      [ws_pid: ws_pid]
    end

    test "validate message test is received by the client", %{ws_pid: ws_pid} do
      GunTest.receive_message(ws_pid, "test")
      assert :sys.get_state(ws_pid).internal_state.message == "test"
    end
  end

  ```
  """

  @impl Shogun.Websocket.Client
  def connect(state) do
    send(self(), {:gun_upgrade, self(), nil, nil, []})

    {:noreply, state}
  end

  def receive_message(pid, message) when is_binary(message) do
    event = {:gun_ws, nil, nil, {:text, message}}
    send(pid, event)
  end
end
