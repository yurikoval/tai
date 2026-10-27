defmodule Tai.VenueAdapters.OkEx.Stream.PublicConnection do
  use Tai.Venues.Streams.ConnectionAdapter
  alias Tai.VenueAdapters.OkEx.Stream

  @type stream :: Tai.Venues.Stream.t()
  @type endpoint :: String.t()

  @spec start_link(endpoint: endpoint, stream: stream) :: {:ok, pid}
  def start_link(endpoint: endpoint, stream: stream) do
    routes = %{
      markets: Stream.RouteOrderBooks.to_name(stream.venue.id),
      optional_channels: Stream.ProcessOptionalChannels.to_name(stream.venue.id)
    }

    state = %Tai.Venues.Streams.ConnectionAdapter.State{
      venue: stream.venue.id,
      routes: routes,
      channels: stream.venue.channels,
      credential: nil,
      markets: stream.markets,
      quote_depth: stream.venue.quote_depth,
      heartbeat_interval: stream.venue.stream_heartbeat_interval,
      heartbeat_timeout: stream.venue.stream_heartbeat_timeout,
      compression: nil,
      opts: stream.venue.opts
    }

    WebSockex.start_link(endpoint, __MODULE__, state, name: process_name(stream.venue.id))
  end

  def reconnect(venue) do
    case Process.whereis(process_name(venue)) do
      nil -> :ok
      connection -> WebSockex.cast(connection, :reconnect)
    end
  end

  @optional_channels [:trades]

  @impl true
  def subscribe(:init, state) do
    send(self(), {:subscribe, :depth})

    Enum.each(state.channels, fn channel ->
      if channel in @optional_channels do
        send(self(), {:subscribe, channel})
      else
        TaiEvents.warning(%Tai.Events.StreamChannelInvalid{
          venue: state.venue,
          name: channel,
          available: @optional_channels
        })
      end
    end)

    {:ok, state}
  end

  @impl true
  def subscribe(:depth, state), do: send_subscription(state, &Stream.Channels.depth/1)

  @impl true
  def subscribe(:trades, state), do: send_subscription(state, &Stream.Channels.trade/1)

  @impl true
  def heartbeat_frame(_state), do: {:text, "ping"}

  @impl true
  def handle_cast(:reconnect, state) do
    {:close, {1000, "order book sequence gap"}, state}
  end

  @impl true
  def on_disconnect(_conn_status, state) do
    Stream.RouteOrderBooks.reset(state.venue)
    {:ok, state}
  end

  @impl true
  def on_msg(
        %{"action" => action, "arg" => %{"channel" => "books"}} = msg,
        received_at,
        state
      )
      when action in ["snapshot", "update"] do
    forward(msg, :markets, received_at, state)
    {:ok, state}
  end

  def on_msg(msg, received_at, state) do
    forward(msg, :optional_channels, received_at, state)
    {:ok, state}
  end

  defp send_subscription(%{markets: []} = state, _channel), do: {:ok, state}

  defp send_subscription(state, channel) do
    args = Enum.map(state.markets, channel)
    msg = Jason.encode!(%{op: "subscribe", args: args})
    {:reply, {:text, msg}, state}
  end

  defp forward(msg, to, received_at, state) do
    state.routes
    |> Map.fetch!(to)
    |> GenServer.cast({msg, received_at})
  end
end
