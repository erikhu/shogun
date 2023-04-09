defmodule Shogun.Websocket.GunTest do
  # only intended to be used inside of websocket.ex
  def connect(state) do
    send(self(), {:gun_upgrade, self(), nil, nil, []})

    {:noreply, state}
  end

  def receive_message(pid, message) when is_binary(message) do
    event = {:gun_ws, nil, nil, {:text, message}}
    send(pid, event)
  end
end
