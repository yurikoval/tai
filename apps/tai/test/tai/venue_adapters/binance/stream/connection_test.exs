defmodule Tai.VenueAdapters.Binance.Stream.ConnectionTest do
  use ExUnit.Case, async: false
  import Mock
  alias Tai.Markets.OrderBook
  alias Tai.VenueAdapters.Binance.Stream.{Connection, ProcessOrderBook}
  alias Tai.Venues.Streams.ConnectionAdapter

  test "tracks and clears subscription request ids" do
    product =
      struct(Tai.Venues.Product,
        venue_id: :binance,
        symbol: :btcusdt,
        venue_symbol: "BTCUSDT",
        type: :spot
      )

    start_supervised!(OrderBook.child_spec(product, 1, false))
    start_supervised!({ProcessOrderBook, [product: product, snapshot_depth: 5]})

    state = %ConnectionAdapter.State{
      venue: :binance,
      routes: %{},
      channels: [],
      markets: [product],
      quote_depth: 1,
      heartbeat_interval: 5_000,
      heartbeat_timeout: 3_000,
      opts: %{},
      requests: %ConnectionAdapter.Requests{next_request_id: 1, pending_requests: %{}}
    }

    assert {:reply, {:text, _msg}, subscribed} = Connection.subscribe(:depth, state)
    assert subscribed.requests.pending_requests[1] == :depth
    assert subscribed.requests.next_request_id == 2

    with_mock ExBinance.Rest.SpotClient,
      get: fn "/api/v3/depth", %{symbol: "BTCUSDT", limit: 5} ->
        {:ok, %{"lastUpdateId" => 100, "bids" => [], "asks" => []}}
      end do
      assert {:ok, acknowledged} =
               Connection.on_msg(%{"id" => 1, "result" => nil}, 0, subscribed)

      assert acknowledged.requests.pending_requests == %{}
    end
  end
end
