defmodule Tai.VenueAdapters.OkEx.Stream.ProcessOrderBookTest do
  use Tai.TestSupport.DataCase, async: false
  alias Tai.Markets.{OrderBook, PricePoint, Quote}
  alias Tai.VenueAdapters.OkEx.Stream.{ProcessOrderBook, PublicConnection, RouteOrderBooks}

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
    start_supervised!({RouteOrderBooks, [venue: @product.venue_id, order_books: [@product]]})
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

  test "accepts an empty snapshot before later updates", %{pid: pid} do
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

  test "rejects updates before a synchronized snapshot", %{pid: pid} do
    register_connection()

    GenServer.cast(pid, {:update, update(%{"prevSeqId" => nil}), Timex.now()})

    assert_receive {:connection_message, {:"$websockex_cast", :reconnect}}
    refute_receive %Quote{}
    assert %{sequence_id: nil} = :sys.get_state(pid)
  end

  test "rejects non-integer previous sequence ids", %{pid: pid} do
    register_connection()

    GenServer.cast(pid, {:snapshot, snapshot(), Timex.now()})
    assert_receive %Quote{}

    GenServer.cast(pid, {:update, update(%{"prevSeqId" => "10"}), Timex.now()})

    assert_receive {:connection_message, {:"$websockex_cast", :reconnect}}
    refute_receive %Quote{}
    assert %{sequence_id: nil} = :sys.get_state(pid)
  end

  test "rejects invalid snapshot and update sequence domains", %{pid: pid} do
    register_connection()

    invalid_snapshots = [
      snapshot(%{"prevSeqId" => 5}),
      snapshot(%{"seqId" => -1})
    ]

    Enum.each(invalid_snapshots, fn invalid_snapshot ->
      GenServer.cast(pid, {:snapshot, invalid_snapshot, Timex.now()})
      assert_receive {:connection_message, {:"$websockex_cast", :reconnect}}
      refute_receive %Quote{}
      assert %{sequence_id: nil} = :sys.get_state(pid)
    end)

    invalid_updates = [
      update(%{"prevSeqId" => -1}),
      update(%{"seqId" => -1})
    ]

    Enum.each(invalid_updates, fn invalid_update ->
      GenServer.cast(pid, {:snapshot, snapshot(), Timex.now()})
      assert_receive %Quote{}

      GenServer.cast(pid, {:update, invalid_update, Timex.now()})
      assert_receive {:connection_message, {:"$websockex_cast", :reconnect}}
      refute_receive %Quote{}
      assert %{sequence_id: nil} = :sys.get_state(pid)
    end)
  end

  test "advances sequence ids for empty updates", %{pid: pid} do
    GenServer.cast(pid, {:snapshot, snapshot(), Timex.now()})
    assert_receive %Quote{}

    GenServer.cast(pid, {:update, update(%{}), Timex.now()})

    refute_receive %Quote{}
    assert %{sequence_id: 11} = :sys.get_state(pid)

    GenServer.cast(
      pid,
      {:update,
       update(%{
         "prevSeqId" => 11,
         "seqId" => 12,
         "bids" => [["100", "11", "0", "2"]]
       }), Timex.now()}
    )

    assert_receive %Quote{bids: [%PricePoint{price: 100.0, size: 11.0}]}
    assert %{sequence_id: 12} = :sys.get_state(pid)
  end

  test "accepts equal sequence ids only for empty keepalives", %{pid: pid} do
    register_connection()

    GenServer.cast(pid, {:snapshot, snapshot(), Timex.now()})
    assert_receive %Quote{}

    GenServer.cast(
      pid,
      {:update, update(%{"seqId" => 10, "bids" => [], "asks" => []}), Timex.now()}
    )

    refute_receive {:connection_message, {:"$websockex_cast", :reconnect}}
    refute_receive %Quote{}
    assert %{sequence_id: 10} = :sys.get_state(pid)
  end

  test "rejects equal sequence ids that change either side", %{pid: pid} do
    register_connection()

    changes = [
      %{"bids" => [["100", "11", "0", "2"]]},
      %{"asks" => [["101", "6", "0", "2"]]}
    ]

    Enum.each(changes, fn change ->
      GenServer.cast(pid, {:snapshot, snapshot(), Timex.now()})
      assert_receive %Quote{}

      GenServer.cast(pid, {:update, update(Map.put(change, "seqId", 10)), Timex.now()})

      assert_receive {:connection_message, {:"$websockex_cast", :reconnect}}
      refute_receive %Quote{}
      assert %{sequence_id: nil} = :sys.get_state(pid)
    end)
  end

  test "accepts lower sequence ids used by maintenance resets", %{pid: pid} do
    GenServer.cast(pid, {:snapshot, snapshot(), Timex.now()})
    assert_receive %Quote{}

    GenServer.cast(
      pid,
      {:update,
       update(%{
         "seqId" => 5,
         "bids" => [["100", "11", "0", "2"]]
       }), Timex.now()}
    )

    assert_receive %Quote{bids: [%PricePoint{price: 100.0, size: 11.0}]}
    assert %{sequence_id: 5} = :sys.get_state(pid)
  end

  test "clears synchronization and reconnects after an invalid snapshot", %{pid: pid} do
    register_connection()
    GenServer.cast(pid, {:snapshot, snapshot(), Timex.now()})
    assert_receive %Quote{}
    assert %{sequence_id: 10} = :sys.get_state(pid)

    GenServer.cast(pid, {:snapshot, snapshot(%{"ts" => "invalid"}), Timex.now()})

    assert_receive {:connection_message, {:"$websockex_cast", :reconnect}}
    refute_receive %Quote{}
    assert %{sequence_id: nil} = :sys.get_state(pid)
  end

  test "requires both book sides and valid numeric domains", %{pid: pid} do
    register_connection()

    invalid_snapshots = [
      Map.delete(snapshot(), "asks"),
      snapshot(%{"bids" => [["0", "10", "0", "1"]]}),
      snapshot(%{"asks" => [["101", "-1", "0", "1"]]})
    ]

    Enum.each(invalid_snapshots, fn invalid_snapshot ->
      GenServer.cast(pid, {:snapshot, invalid_snapshot, Timex.now()})
      assert_receive {:connection_message, {:"$websockex_cast", :reconnect}}
      refute_receive %Quote{}
      assert %{sequence_id: nil} = :sys.get_state(pid)
    end)
  end

  test "invalidates synchronization after a malformed contiguous update", %{pid: pid} do
    register_connection()
    GenServer.cast(pid, {:snapshot, snapshot(), Timex.now()})
    assert_receive %Quote{}

    GenServer.cast(pid, {:update, update(%{"ts" => "invalid"}), Timex.now()})

    assert_receive {:connection_message, {:"$websockex_cast", :reconnect}}
    refute_receive %Quote{}
    assert %{sequence_id: nil} = :sys.get_state(pid)
  end

  test "reconnects instead of applying an update after a sequence gap", %{pid: pid} do
    register_connection()

    GenServer.cast(pid, {:snapshot, snapshot(), Timex.now()})
    assert_receive %Quote{}

    GenServer.cast(pid, {:update, update(%{"prevSeqId" => 99}), Timex.now()})

    assert_receive {:connection_message, {:"$websockex_cast", :reconnect}}
    refute_receive %Quote{}
  end

  defp register_connection do
    parent = self()

    connection = spawn(fn -> forward_connection_messages(parent) end)
    Process.register(connection, PublicConnection.process_name(@product.venue_id))
    on_exit(fn -> if Process.alive?(connection), do: Process.exit(connection, :kill) end)
  end

  defp forward_connection_messages(parent) do
    receive do
      message ->
        send(parent, {:connection_message, message})
        forward_connection_messages(parent)
    end
  end

  defp snapshot(overrides \\ %{}) do
    Map.merge(
      %{
        "ts" => "1546663386309",
        "prevSeqId" => -1,
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
