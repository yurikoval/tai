defmodule Tai.VenueAdapters.OkEx.Stream.RouteOrderBooksTest do
  use ExUnit.Case, async: false
  alias Tai.VenueAdapters.OkEx.Stream.{ProcessOrderBook, RouteOrderBooks}

  @venue :venue_a
  @venue_symbol "BTC-USD-SWAP"
  @product struct(Tai.Venues.Product, venue_id: @venue, venue_symbol: @venue_symbol)
  @received_at Timex.now()

  setup do
    Process.register(self(), ProcessOrderBook.to_name(@venue, @venue_symbol))
    {:ok, pid} = start_supervised({RouteOrderBooks, [venue: @venue, order_books: [@product]]})

    %{pid: pid}
  end

  test "forwards a V5 snapshot using arg.instId", %{pid: pid} do
    data = %{"ts" => "1546663386310", "bids" => [], "asks" => []}

    venue_msg = %{
      "arg" => %{"channel" => "books", "instId" => @venue_symbol},
      "action" => "snapshot",
      "data" => [data]
    }

    GenServer.cast(pid, {venue_msg, @received_at})

    assert_receive {:"$gen_cast", {:snapshot, ^data, @received_at}}
  end

  test "forwards a V5 update using arg.instId", %{pid: pid} do
    data = %{"ts" => "1546663387456", "bids" => [], "asks" => []}

    venue_msg = %{
      "arg" => %{"channel" => "books", "instId" => @venue_symbol},
      "action" => "update",
      "data" => [data]
    }

    GenServer.cast(pid, {venue_msg, @received_at})

    assert_receive {:"$gen_cast", {:update, ^data, @received_at}}
  end

  test "ignores malformed and unknown product messages without crashing", %{pid: pid} do
    GenServer.cast(pid, {%{"arg" => %{"channel" => "books"}}, @received_at})

    GenServer.cast(
      pid,
      {%{
         "arg" => %{"channel" => "books", "instId" => "UNKNOWN"},
         "action" => "snapshot",
         "data" => [%{}]
       }, @received_at}
    )

    assert %RouteOrderBooks.State{} = :sys.get_state(pid)
  end
end
