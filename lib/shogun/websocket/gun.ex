defmodule Shogun.Websocket.Gun do
  def connect(%{uri: uri, open_opts: open_opts} = state) do
    with {:ok, conn_pid} <- :gun.open(String.to_charlist(uri.host), uri.port, open_opts) do
      state = Map.put(state, :conn_pid, conn_pid)

      {:noreply, state}
    end
  end
end
