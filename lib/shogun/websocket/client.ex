defmodule Shogun.Websocket.Client do
  @type state :: Shogun.Websocket.state()

  @doc """
  Only intented to be used inside the `websocket.ex` file after init
  """
  @callback connect(state) :: {:noreply, state()}
end
