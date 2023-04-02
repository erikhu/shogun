# Gundam

Elixir websocket client powered by [Gun (erlang)](https://ninenines.eu/docs/en/gun/2.0/manual/)

example of usage
```elixir
defmodule MyWebsocket do
  use Gundam.Websocket
end
```

it can be used also the callbacks:

```elixir
  @doc """
  trigger when the websocket client connects successfully
  """
  @callback on_connect(headers(), pid(), state()) :: state()

  @doc """
  trigger when the connection is lost (gun will try to connect again and upgrade to ws)
  """
  @callback on_disconnect(pid(), state()) :: state()

  @doc """
  trigger when the websocket client fails to connect successfully
  """
  @callback on_close(code(), reason(), pid(), state()) :: state()

  @doc """
  trigger when the websocket client has abruptly an error
  """
  @callback on_error(reason(), pid(), state()) :: state()

  @doc """
  trigger when the websocket client recieves an message from the server
  """
  @callback on_message(message(), pid(), state()) :: state()
```

like

```elixir

defmodule MyWebsocket do
  use Gundam.Websocket
  
  @impl Gundam.Websocket
  def on_connect(_headers, _pid, state) do
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
    {:gundam, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at <https://hexdocs.pm/gundam>.

