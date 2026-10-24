defmodule Tai.VenueAdapters.Binance.Stream.ProcessOrderBookTest do
  use Tai.TestSupport.DataCase, async: false
  alias Tai.VenueAdapters.Binance.Stream.ProcessOrderBook
  alias Tai.Markets.{OrderBook, PricePoint, Quote}

  @product struct(Tai.Venues.Product,
             venue_id: :venue_a,
             symbol: :xbtusd,
             venue_symbol: "XBTUSD"
           )
  @order_book_name OrderBook.to_name(@product.venue_id, @product.venue_symbol)
  @quote_depth 1

  setup do
    Process.register(self(), @order_book_name)
    start_supervised!(OrderBook.child_spec(@product, @quote_depth, false))
    {:ok, pid} = start_supervised({ProcessOrderBook, @product})
    Tai.Markets.subscribe_quote(@product.venue_id)

    {:ok, %{pid: pid}}
  end

  test "can insert new price points into the order book", %{pid: pid} do
    data = %{
      "E" => 1_569_054_255_636,
      "s" => @product.venue_symbol,
      "b" => [["100", "15"]],
      "a" => [["101", "11"]]
    }

    GenServer.cast(pid, {:update, data, Timex.now()})

    assert_receive %Quote{} = market_quote
    assert Enum.count(market_quote.bids) == 1
    assert Enum.at(market_quote.bids, 0) == %PricePoint{price: 100.0, size: 15.0}
    assert Enum.count(market_quote.asks) == 1
    assert Enum.at(market_quote.asks, 0) == %PricePoint{price: 101.0, size: 11.0}
    assert %DateTime{} = market_quote.last_venue_timestamp
    assert market_quote.last_received_at != nil
  end

  test "can update existing price points in the order book", %{pid: pid} do
    snapshot =
      struct(OrderBook.ChangeSet,
        venue: @product.venue_id,
        symbol: @product.symbol,
        changes: [
          {:upsert, :bid, 100.0, 5.0},
          {:upsert, :ask, 101.0, 10.0}
        ]
      )

    OrderBook.replace(snapshot)

    assert_receive %Quote{} = _

    data = %{
      "E" => 1_569_054_255_636,
      "s" => @product.venue_symbol,
      "b" => [["100", "15"]],
      "a" => [["101", "11"]]
    }

    GenServer.cast(pid, {:update, data, Timex.now()})

    assert_receive %Quote{} = market_quote
    assert Enum.count(market_quote.bids) == 1
    assert Enum.at(market_quote.bids, 0) == %PricePoint{price: 100.0, size: 15.0}
    assert Enum.count(market_quote.asks) == 1
    assert Enum.at(market_quote.asks, 0) == %PricePoint{price: 101.0, size: 11.0}
    assert %DateTime{} = market_quote.last_venue_timestamp
    assert market_quote.last_received_at != nil
  end

  test "accepts the first spot event after the snapshot", %{pid: pid} do
    spot_product = %{@product | type: :spot}

    :sys.replace_state(pid, &%{&1 | product: spot_product, last_update_id: 100, bridged: false})

    data = %{
      "E" => 1_569_054_255_636,
      "s" => @product.venue_symbol,
      "U" => 101,
      "u" => 101,
      "b" => [["100", "15"]],
      "a" => [["101", "11"]]
    }

    GenServer.cast(pid, {:update, data, Timex.now()})

    assert_receive %Quote{} = market_quote
    assert Enum.at(market_quote.bids, 0) == %PricePoint{price: 100.0, size: 15.0}
  end

  test "accepts the first futures event that bridges the snapshot", %{pid: pid} do
    :sys.replace_state(pid, &%{&1 | last_update_id: 100, bridged: false})

    data = %{
      "E" => 1_569_054_255_636,
      "s" => @product.venue_symbol,
      "U" => 100,
      "u" => 101,
      "pu" => 99,
      "b" => [["100", "15"]],
      "a" => [["101", "11"]]
    }

    GenServer.cast(pid, {:update, data, Timex.now()})

    assert_receive %Quote{} = market_quote
    assert Enum.at(market_quote.bids, 0) == %PricePoint{price: 100.0, size: 15.0}
  end

  test "rejects depth updates with a sequence gap", %{pid: pid} do
    first = %{
      "E" => 1_569_054_255_636,
      "s" => @product.venue_symbol,
      "U" => 1,
      "u" => 1,
      "b" => [["100", "15"]],
      "a" => [["101", "11"]]
    }

    GenServer.cast(pid, {:update, first, Timex.now()})
    assert_receive %Quote{}

    gap = %{
      "E" => 1_569_054_255_637,
      "s" => @product.venue_symbol,
      "U" => 3,
      "u" => 3,
      "b" => [["99", "20"]],
      "a" => []
    }

    GenServer.cast(pid, {:update, gap, Timex.now()})
    refute_receive %Quote{}, 50
  end

  test "can delete existing price points from the order book", %{pid: pid} do
    snapshot =
      struct(OrderBook.ChangeSet,
        venue: @product.venue_id,
        symbol: @product.symbol,
        changes: [
          {:upsert, :bid, 100.0, 5.0},
          {:upsert, :ask, 101.0, 10.0}
        ]
      )

    OrderBook.replace(snapshot)

    assert_receive %Quote{} = _

    data = %{
      "E" => 1_569_054_255_636,
      "s" => @product.venue_symbol,
      "b" => [["100", "0"]],
      "a" => [["101", "0"]]
    }

    GenServer.cast(pid, {:update, data, Timex.now()})

    assert_receive %Quote{} = market_quote
    assert Enum.empty?(market_quote.bids)
    assert Enum.empty?(market_quote.asks)
    assert %DateTime{} = market_quote.last_venue_timestamp
    assert market_quote.last_received_at != nil
  end
end
