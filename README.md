# Gundam

Reliable elixir websocket client powered by [Gun 2.0 (erlang)](https://ninenines.eu/docs/en/gun/2.0/manual/)

Example of usage
```elixir
defmodule MyWebsocket do
  use Gundam.Websocket
end

{:ok, pid} = MyWebsocket.start_link(url: "ws://localhost/websocket")
```

It can be used also the callbacks:

```elixir
  @doc """
  trigger when the websocket client connects successfully
  """
  @callback on_connect(headers(), state()) :: state()

  @doc """
  trigger when the connection is lost (gun will try to connect again and upgrade to ws)
  """
  @callback on_disconnect(reason(), state()) :: state()

  @doc """
  trigger when the websocket client fails to connect successfully
  """
  @callback on_close(code(), state()) :: state()

  @doc """
  trigger when the websocket client has abruptly an error
  """
  @callback on_error(reason(), state()) :: state()

  @doc """
  trigger when the websocket client recieves an message from the server
  """
  @callback on_message(message(), state()) :: state()
```

Using **on_connect/2** callback

```elixir

defmodule MyWebsocket do
  use Gundam.Websocket
  
  @impl Gundam.Websocket
  def on_connect(_headers, state) do
    # Doing something awesome ...
    state
  end
end
```


## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `gundam` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:gundam, "~> 0.1.1"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/gundam>.

