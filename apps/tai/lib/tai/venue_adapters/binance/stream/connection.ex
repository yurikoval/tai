defmodule Tai.VenueAdapters.Binance.Stream.Connection do
  use Tai.Venues.Streams.ConnectionAdapter
  alias Tai.VenueAdapters.Binance.Stream

  @type stream :: Tai.Venues.Stream.t()
  @type venue_id :: Tai.Venue.id()
  @type credential_id :: Tai.Venue.credential_id()
  @type credential :: Tai.Venue.credential()

  @spec start_link(
          endpoint: String.t(),
          stream: stream,
          credential: {credential_id, credential} | nil
        ) :: {:ok, pid}
  def start_link(endpoint: endpoint, stream: stream, credential: credential) do
    routes = %{
      markets: stream.venue.id |> Stream.RouteOrderBooks.to_name(),
      optional_channels: stream.venue.id |> Stream.ProcessOptionalChannels.to_name()
    }

    state = %Tai.Venues.Streams.ConnectionAdapter.State{
      venue: stream.venue.id,
      routes: routes,
      channels: stream.venue.channels,
      credential: credential,
      markets: stream.markets,
      quote_depth: stream.venue.quote_depth,
      heartbeat_interval: stream.venue.stream_heartbeat_interval,
      heartbeat_timeout: stream.venue.stream_heartbeat_timeout,
      opts: stream.venue.opts,
      requests: %Tai.Venues.Streams.ConnectionAdapter.Requests{
        next_request_id: 1,
        pending_requests: %{}
      }
    }

    name = stream.venue.id |> process_name()
    {:ok, pid} = WebSockex.start_link(endpoint, __MODULE__, state, name: name)

    {:ok, pid}
  end

  @optional_channels [
    :trades
  ]
  @impl true
  def subscribe(:init, state) do
    send(self(), {:subscribe, :depth})

    state.channels
    |> Enum.each(fn c ->
      if Enum.member?(@optional_channels, c) do
        send(self(), {:subscribe, c})
      else
        TaiEvents.warning(%Tai.Events.StreamChannelInvalid{
          venue: state.venue,
          name: c,
          available: @optional_channels
        })
      end
    end)

    {:ok, state}
  end

  @impl true
  def subscribe(:depth, state) do
    if Enum.any?(state.markets) do
      channels =
        state.markets
        |> stream_symbols
        |> Enum.map(&"#{&1}@depth@100ms")

      msg =
        %{
          method: "SUBSCRIBE",
          id: state.requests.next_request_id,
          params: channels
        }
        |> Jason.encode!()

      state = state |> add_request()
      {:reply, {:text, msg}, state}
    else
      {:ok, state}
    end
  end

  @impl true
  def subscribe(:trades, state) do
    if Enum.any?(state.markets) do
      channels =
        state.markets
        |> stream_symbols
        |> Enum.map(&"#{&1}@trade")

      msg =
        %{
          method: "SUBSCRIBE",
          id: state.requests.next_request_id,
          params: channels
        }
        |> Jason.encode!()

      state = state |> add_request()
      {:reply, {:text, msg}, state}
    else
      {:ok, state}
    end
  end

  @impl true
  def on_msg(%{"id" => id, "result" => nil}, _received_at, state) do
    pending_requests = Map.delete(state.requests.pending_requests, id)
    requests = %{state.requests | pending_requests: pending_requests}
    {:ok, %{state | requests: requests}}
  end

  @impl true
  def on_msg(%{"e" => "depthUpdate"} = msg, received_at_, state) do
    msg |> forward(:markets, received_at_, state)
    {:ok, state}
  end

  @impl true
  def on_msg(msg, received_at_, state) do
    msg |> forward(:optional_channels, received_at_, state)
    {:ok, state}
  end

  defp stream_symbols(markets) do
    markets
    |> Enum.map(& &1.venue_symbol)
    |> Enum.map(&String.downcase/1)
  end

  defp forward(msg, to, received_at, state) do
    state.routes
    |> Map.fetch!(to)
    |> GenServer.cast({msg, received_at})
  end
end
