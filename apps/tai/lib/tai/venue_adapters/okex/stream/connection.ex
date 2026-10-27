defmodule Tai.VenueAdapters.OkEx.Stream.Connection do
  use Tai.Venues.Streams.ConnectionAdapter
  alias Tai.VenueAdapters.OkEx.Stream

  @moduledoc false

  @type stream :: Tai.Venues.Stream.t()
  @type endpoint :: String.t()
  @type credential_id :: Tai.Venue.credential_id()
  @type credential :: Tai.Venue.account()

  @spec start_link(
          endpoint: endpoint,
          stream: stream,
          credential: {credential_id, credential}
        ) :: {:ok, pid}
  def start_link(endpoint: endpoint, stream: stream, credential: credential) do
    state = %Tai.Venues.Streams.ConnectionAdapter.State{
      venue: stream.venue.id,
      routes: %{auth: Stream.ProcessAuth.process_name(stream.venue.id)},
      channels: [],
      credential: credential,
      markets: stream.markets,
      quote_depth: stream.venue.quote_depth,
      heartbeat_interval: stream.venue.stream_heartbeat_interval,
      heartbeat_timeout: stream.venue.stream_heartbeat_timeout,
      compression: :unzip,
      opts: stream.venue.opts
    }

    WebSockex.start_link(endpoint, __MODULE__, state, name: process_name(stream.venue.id))
  end

  @impl true
  def subscribe(:init, state) do
    send(self(), {:subscribe, :login})
    {:ok, state}
  end

  @impl true
  def subscribe(:login, state) do
    args = Stream.Auth.args(state.credential)
    msg = Jason.encode!(%{op: "login", args: args})
    {:reply, {:text, msg}, state}
  end

  @impl true
  def subscribe(:orders, state) do
    args = Enum.map(state.markets, &Stream.Channels.order/1)
    msg = Jason.encode!(%{op: "subscribe", args: args})
    {:reply, {:text, msg}, state}
  end

  @impl true
  def on_msg(
        %{"event" => "login", "success" => true},
        _received_at,
        %_{credential: {credential_id, _}} = state
      ) do
    TaiEvents.info(%Tai.Events.StreamAuthOk{
      venue: state.venue,
      credential: credential_id
    })

    send(self(), {:subscribe, :orders})
    {:ok, state}
  end

  @order_tables ~w(futures/order swap/order spot/order)

  @impl true
  def on_msg(%{"table" => table} = msg, received_at, state) when table in @order_tables do
    forward(msg, received_at, state)
    {:ok, state}
  end

  @impl true
  def on_msg(msg, received_at, state) do
    forward(msg, received_at, state)
    {:ok, state}
  end

  defp forward(msg, received_at, state) do
    state.routes.auth
    |> GenServer.cast({msg, received_at})
  end
end
