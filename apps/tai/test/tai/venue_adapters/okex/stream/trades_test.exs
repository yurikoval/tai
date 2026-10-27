defmodule Tai.VenueAdapters.OkEx.Stream.TradesTest do
  use Tai.TestSupport.DataCase, async: false
  import Tai.TestSupport.Assertions.Event
  alias Tai.VenueAdapters.OkEx.Stream.ProcessOptionalChannels

  @product struct(Tai.Venues.Product,
             venue_id: :my_venue,
             symbol: :configured_xperp,
             venue_symbol: "0G-USD_UM_XPERP-310905"
           )

  test "broadcasts the existing Trade event from a V5 public trade" do
    start_supervised!({ProcessOptionalChannels, [venue: :my_venue, markets: [@product]]})
    TaiEvents.firehose_subscribe()
    received_at = Tai.Time.monotonic_time()

    :my_venue
    |> ProcessOptionalChannels.to_name()
    |> GenServer.cast(
      {%{
         "arg" => %{
           "channel" => "trades",
           "instId" => "0G-USD_UM_XPERP-310905"
         },
         "data" => [
           %{
             "instId" => "0G-USD_UM_XPERP-310905",
             "tradeId" => "12345",
             "px" => "5556.91",
             "sz" => "5",
             "side" => "sell",
             "ts" => "1546663177496"
           }
         ]
       }, received_at}
    )

    assert_event(trade = %Tai.Events.Trade{})
    assert trade.venue_id == :my_venue
    assert trade.symbol == :configured_xperp
    assert trade.venue_trade_id == "12345"
    assert trade.received_at == received_at
    assert trade.timestamp == DateTime.from_unix!(1_546_663_177_496, :millisecond)
    assert trade.qty == Decimal.new(5)
    assert trade.price == Decimal.new("5556.91")
    assert trade.taker_side == :sell
  end

  test "logs and ignores malformed V5 trade payloads" do
    pid =
      start_supervised!({ProcessOptionalChannels, [venue: :my_venue, markets: [@product]]})

    TaiEvents.firehose_subscribe()
    received_at = Tai.Time.monotonic_time()

    GenServer.cast(pid, {
      %{
        "arg" => %{"channel" => "trades", "instId" => @product.venue_symbol},
        "data" => [
          %{},
          %{
            "instId" => "BTC-USDT",
            "tradeId" => "1",
            "px" => "invalid",
            "sz" => "2",
            "side" => "unknown",
            "ts" => "invalid"
          }
        ]
      },
      received_at
    })

    GenServer.cast(pid, {%{"arg" => %{"channel" => "trades"}, "data" => %{}}, received_at})

    assert_event(%Tai.Events.StreamMessageUnhandled{}, :warning)
    assert_event(%Tai.Events.StreamMessageUnhandled{}, :warning)
    assert_event(%Tai.Events.StreamMessageUnhandled{}, :warning)
    assert %ProcessOptionalChannels.State{} = :sys.get_state(pid)
  end

  test "rejects mismatched, unknown, and invalid-domain trades" do
    pid =
      start_supervised!({ProcessOptionalChannels, [venue: :my_venue, markets: [@product]]})

    TaiEvents.firehose_subscribe()
    received_at = Tai.Time.monotonic_time()

    invalid_records = [
      valid_trade(%{"instId" => "OTHER"}),
      valid_trade(%{"tradeId" => ""}),
      valid_trade(%{"px" => "0"}),
      valid_trade(%{"px" => "Infinity"}),
      valid_trade(%{"sz" => "-1"}),
      valid_trade(%{"ts" => "-1"})
    ]

    GenServer.cast(pid, {
      %{
        "arg" => %{"channel" => "trades", "instId" => @product.venue_symbol},
        "data" => invalid_records
      },
      received_at
    })

    GenServer.cast(pid, {
      %{
        "arg" => %{"channel" => "trades", "instId" => "UNKNOWN"},
        "data" => [valid_trade(%{"instId" => "UNKNOWN"})]
      },
      received_at
    })

    Enum.each(1..7, fn _ -> assert_event(%Tai.Events.StreamMessageUnhandled{}, :warning) end)
    refute_event(%Tai.Events.Trade{})
    assert %ProcessOptionalChannels.State{} = :sys.get_state(pid)
  end

  defp valid_trade(overrides) do
    Map.merge(
      %{
        "instId" => @product.venue_symbol,
        "tradeId" => "12345",
        "px" => "5556.91",
        "sz" => "5",
        "side" => "sell",
        "ts" => "1546663177496"
      },
      overrides
    )
  end
end
