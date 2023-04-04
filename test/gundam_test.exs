defmodule GundamTest do
  use ExUnit.Case, async: true

  alias Gundam.WebsocketHelper
  alias Gundam.WebsocketTest

  @protocol_options [
    idle_timeout: 1000,
    request_timeout: 1000
  ]

  setup context do
    scheme = Map.get(context, :scheme, :http)
    :tls_certificate_check.override_trusted_authorities({:file, ssl_file("ca_and_chain.pem")})

    {:ok, ws_server_pid} = start_supervised(plug_cowboy(scheme), id: :test_ws_server)

    ws_server_info = WebsocketHelper.ws_server_info(scheme)
    [ws_server_pid: ws_server_pid, ws_server_info: ws_server_info, scheme: scheme]
  end

  test "unsecure connect to websocket server", %{ws_server_info: ws_server_info} do
    {:ok, ws_pid} =
      start_supervised({WebsocketTest, url: "ws://localhost:#{ws_server_info[:port]}/"})

    wait_for(1000, fn ->
      assert :sys.get_state(ws_pid).connected
    end)
  end

  @tag scheme: :https
  test "secure connect to websocket server", %{ws_server_info: ws_server_info} do
    {:ok, ws_pid} =
      start_supervised({
        WebsocketTest,
        [
          url: "wss://localhost:#{ws_server_info[:port]}/"
        ]
      })

    wait_for(1000, fn ->
      assert :sys.get_state(ws_pid).connected
    end)
  end

  test "reconnect automatically when server fails",
       %{ws_server_info: ws_server_info, scheme: scheme} do
    {:ok, ws_pid} =
      start_supervised(
        {WebsocketTest, url: "ws://localhost:#{ws_server_info[:port]}/", retry_timeout: 500}
      )

    wait_for(1000, fn ->
      assert :sys.get_state(ws_pid).connected
    end)

    stop_supervised!(:test_ws_server)

    wait_for(1000, fn ->
      refute :sys.get_state(ws_pid).connected
    end)

    start_supervised(plug_cowboy(scheme, ws_server_info[:port]))

    wait_for(10000, fn ->
      assert :sys.get_state(ws_pid).connected
    end)
  end

  defp wait_for(timeout, cb) when timeout <= 0 do
    cb.()
  end

  defp wait_for(timeout, cb) do
    cb.()
  rescue
    _ ->
      Process.sleep(100)
      wait_for(timeout - 100, cb)
  end

  defp https_options(:https) do
    [
      password: "gundam",
      keyfile: ssl_file("server_key_enc.pem"),
      certfile: ssl_file("valid.pem"),
      cacertfile: ssl_file("valid.pem")
    ]
  end

  defp https_options(_http), do: []

  defp ssl_file(file) do
    Path.expand("./fixtures/ssl/#{file}", __DIR__)
  end

  defp plug_cowboy(scheme, port \\ 0) do
    {
      Plug.Adapters.Cowboy,
      [
        scheme: scheme,
        plug: WebsocketHelper,
        options: [port: port, protocol_options: @protocol_options]
      ] ++ https_options(scheme)
    }
  end
end
