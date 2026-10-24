defmodule Tai.VenueAdapters.Binance.Stream.ConnectionTest do
  use ExUnit.Case, async: true
  alias Tai.VenueAdapters.Binance.Stream.Connection
  alias Tai.Venues.Streams.ConnectionAdapter

  test "tracks and clears subscription request ids" do
    state = %ConnectionAdapter.State{
      venue: :binance,
      routes: %{},
      channels: [],
      markets: [struct(Tai.Venues.Product, venue_symbol: "BTCUSDT")],
      quote_depth: 1,
      heartbeat_interval: 5_000,
      heartbeat_timeout: 3_000,
      opts: %{},
      requests: %ConnectionAdapter.Requests{next_request_id: 1, pending_requests: %{}}
    }

    assert {:reply, {:text, _msg}, subscribed} = Connection.subscribe(:depth, state)
    assert Map.has_key?(subscribed.requests.pending_requests, 1)
    assert subscribed.requests.next_request_id == 2

    assert {:ok, acknowledged} = Connection.on_msg(%{"id" => 1, "result" => nil}, 0, subscribed)
    assert acknowledged.requests.pending_requests == %{}
  end
end
