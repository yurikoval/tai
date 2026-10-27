defmodule Tai.VenueAdapters.OkEx.Stream.RouteOrderBooksTest do
  use ExUnit.Case, async: false
  alias Tai.VenueAdapters.OkEx.Stream.{ProcessOrderBook, PublicConnection, RouteOrderBooks}

  @venue :venue_a
  @venue_symbol "BTC-USD-SWAP"
  @product struct(Tai.Venues.Product, venue_id: @venue, venue_symbol: @venue_symbol)
  @received_at Tai.Time.monotonic_time()

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

  test "resets every book and reconnects after malformed snapshot envelopes", %{pid: pid} do
    register_connection()

    messages = [
      %{
        "arg" => %{"channel" => "books", "instId" => @venue_symbol},
        "action" => "snapshot",
        "data" => []
      },
      %{
        "arg" => %{"channel" => "books", "instId" => @venue_symbol},
        "action" => "snapshot"
      },
      %{
        "arg" => %{"channel" => "books", "instId" => @venue_symbol},
        "action" => "snapshot",
        "data" => [%{}, %{}]
      }
    ]

    Enum.each(messages, fn msg ->
      GenServer.cast(pid, {msg, @received_at})
      assert_receive {:"$gen_cast", :reset}
      assert_receive {:connection_message, {:"$websockex_cast", :reconnect}}
    end)

    assert %RouteOrderBooks.State{} = :sys.get_state(pid)
  end

  test "resets books when the public connection is replaced", %{pid: pid} do
    assert {:ok, %{venue: @venue}} = PublicConnection.on_disconnect(%{}, %{venue: @venue})
    assert_receive {:"$gen_cast", :reset}
    assert %RouteOrderBooks.State{} = :sys.get_state(pid)
  end

  defp register_connection do
    parent = self()

    connection = spawn(fn -> forward_connection_messages(parent) end)
    Process.register(connection, PublicConnection.process_name(@venue))
    on_exit(fn -> if Process.alive?(connection), do: Process.exit(connection, :kill) end)
  end

  defp forward_connection_messages(parent) do
    receive do
      message ->
        send(parent, {:connection_message, message})
        forward_connection_messages(parent)
    end
  end
end
