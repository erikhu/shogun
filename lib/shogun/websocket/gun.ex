defmodule Shogun.Websocket.Gun do
  @behaviour Shogun.Websocket.Client

  @impl Shogun.Websocket.Client
  def connect(%{uri: uri, open_opts: open_opts} = state) do
    :gun.open(String.to_charlist(uri.host), uri.port, open_opts)
  end
end
