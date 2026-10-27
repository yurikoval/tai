defmodule Tai.VenueAdapters.OkEx.Stream.ProcessOrderBookTest do
  use Tai.TestSupport.DataCase, async: false
  alias Tai.Markets.{OrderBook, PricePoint, Quote}
  alias Tai.VenueAdapters.OkEx.Stream.{ProcessOrderBook, PublicConnection}

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

    %{pid: pid}
  end

  test "snapshots V5 four-field levels and Unix-millisecond timestamps", %{pid: pid} do
    GenServer.cast(pid, {:snapshot, snapshot(), Timex.now()})

    assert_receive %Quote{} = quote
    assert quote.last_venue_timestamp == DateTime.from_unix!(1_546_663_386_309, :millisecond)
    assert quote.bids == [%PricePoint{price: 100.0, size: 10.0}]
    assert quote.asks == [%PricePoint{price: 101.0, size: 5.0}]
  end

  test "inserts V5 four-field updates after a snapshot", %{pid: pid} do
    GenServer.cast(pid, {:snapshot, snapshot(%{"bids" => [], "asks" => []}), Timex.now()})
    assert_receive %Quote{}

    GenServer.cast(
      pid,
      {:update,
       update(%{
         "bids" => [["100", "110", "0", "1"]],
         "asks" => [["111", "50", "0", "1"]]
       }), Timex.now()}
    )

    assert_receive %Quote{} = quote
    assert quote.bids == [%PricePoint{price: 100.0, size: 110.0}]
    assert quote.asks == [%PricePoint{price: 111.0, size: 50.0}]
  end

  test "applies V5 four-field updates", %{pid: pid} do
    GenServer.cast(pid, {:snapshot, snapshot(), Timex.now()})
    assert_receive %Quote{}

    GenServer.cast(
      pid,
      {:update,
       update(%{
         "bids" => [["100", "110", "0", "2"]],
         "asks" => [["101", "50", "0", "2"]]
       }), Timex.now()}
    )

    assert_receive %Quote{} = quote
    assert quote.bids == [%PricePoint{price: 100.0, size: 110.0}]
    assert quote.asks == [%PricePoint{price: 101.0, size: 50.0}]
  end

  test "deletes V5 levels whose size is zero", %{pid: pid} do
    GenServer.cast(pid, {:snapshot, snapshot(), Timex.now()})
    assert_receive %Quote{}

    GenServer.cast(
      pid,
      {:update,
       update(%{
         "bids" => [["100", "0", "0", "0"]],
         "asks" => [["101", "0", "0", "0"]]
       }), Timex.now()}
    )

    assert_receive %Quote{} = quote
    assert Enum.empty?(quote.bids)
    assert Enum.empty?(quote.asks)
  end

  test "reconnects instead of applying an update after a sequence gap", %{pid: pid} do
    parent = self()

    connection =
      spawn(fn ->
        receive do
          message -> send(parent, {:connection_message, message})
        end
      end)

    Process.register(connection, PublicConnection.process_name(@product.venue_id))

    GenServer.cast(pid, {:snapshot, snapshot(), Timex.now()})
    assert_receive %Quote{}

    GenServer.cast(pid, {:update, update(%{"prevSeqId" => 99}), Timex.now()})

    assert_receive {:connection_message, {:"$websockex_cast", :reconnect}}
    refute_receive %Quote{}
  end

  defp snapshot(overrides \\ %{}) do
    Map.merge(
      %{
        "ts" => "1546663386309",
        "seqId" => 10,
        "bids" => [["100", "10", "0", "1"]],
        "asks" => [["101", "5", "0", "1"]]
      },
      overrides
    )
  end

  defp update(overrides) do
    Map.merge(
      %{
        "ts" => "1546663387456",
        "prevSeqId" => 10,
        "seqId" => 11,
        "bids" => [],
        "asks" => []
      },
      overrides
    )
  end
end
