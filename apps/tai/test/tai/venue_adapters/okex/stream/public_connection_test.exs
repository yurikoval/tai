defmodule Tai.VenueAdapters.OkEx.Stream.PublicConnectionTest do
  use ExUnit.Case, async: true
  alias Tai.VenueAdapters.OkEx.Stream.PublicConnection
  alias Tai.Venues.Streams.ConnectionAdapter

  @product struct(Tai.Venues.Product,
             type: :future,
             venue_symbol: "0G-USD_UM_XPERP-310905"
           )

  setup do
    state = %ConnectionAdapter.State{
      venue: :okex,
      routes: %{markets: self(), optional_channels: self()},
      channels: [:trades],
      markets: [@product],
      quote_depth: 20,
      heartbeat_interval: 5_000,
      heartbeat_timeout: 3_000,
      opts: %{}
    }

    %{state: state}
  end

  test ".subscribe/2 encodes a V5 books subscription", %{state: state} do
    assert {:reply, {:text, payload}, returned_state} = PublicConnection.subscribe(:depth, state)
    assert returned_state == state

    assert Jason.decode!(payload) == %{
             "op" => "subscribe",
             "args" => [
               %{"channel" => "books", "instId" => "0G-USD_UM_XPERP-310905"}
             ]
           }
  end

  test ".subscribe/2 encodes a V5 trades subscription", %{state: state} do
    assert {:reply, {:text, payload}, returned_state} = PublicConnection.subscribe(:trades, state)
    assert returned_state == state

    assert Jason.decode!(payload) == %{
             "op" => "subscribe",
             "args" => [
               %{"channel" => "trades", "instId" => "0G-USD_UM_XPERP-310905"}
             ]
           }
  end

  test "sends and accepts the OKX V5 application heartbeat", %{state: state} do
    assert {:reply, {:text, "ping"}, pinging} =
             PublicConnection.handle_info({:heartbeat, :ping}, state)

    assert is_reference(pinging.heartbeat_timeout_timer)
    assert {:ok, ponged} = PublicConnection.handle_frame({:text, "pong"}, pinging)
    assert ponged.heartbeat_timeout_timer == nil
    assert is_reference(ponged.heartbeat_timer)

    assert {:ok, ^ponged} =
             PublicConnection.handle_info(
               {:timeout, pinging.heartbeat_timeout_timer, :heartbeat_timeout},
               ponged
             )

    Process.cancel_timer(ponged.heartbeat_timer)
  end

  test "ignores unsolicited pongs and malformed JSON without crashing", %{state: state} do
    assert {:ok, ^state} = PublicConnection.handle_frame({:text, "pong"}, state)
    assert {:ok, ^state} = PublicConnection.handle_frame({:text, "not-json"}, state)
  end

  test "closes the socket when an order book requests a reconnect", %{state: state} do
    assert {:close, {1000, "order book sequence gap"}, ^state} =
             PublicConnection.handle_cast(:reconnect, state)
  end

  test ".on_msg/3 routes books envelopes to the order-book route", %{state: state} do
    envelope = %{
      "arg" => %{"channel" => "books", "instId" => "BTC-USDT"},
      "action" => "snapshot",
      "data" => [%{"ts" => "1546663386310", "bids" => [], "asks" => []}]
    }

    assert {:ok, ^state} = PublicConnection.on_msg(envelope, 123, state)
    assert_receive {:"$gen_cast", {^envelope, 123}}
  end

  test ".on_msg/3 routes trades envelopes to the optional-channel route", %{state: state} do
    envelope = %{
      "arg" => %{"channel" => "trades", "instId" => "BTC-USDT"},
      "data" => [%{"tradeId" => "1", "px" => "1", "sz" => "2", "ts" => "1546663386310"}]
    }

    assert {:ok, ^state} = PublicConnection.on_msg(envelope, 456, state)
    assert_receive {:"$gen_cast", {^envelope, 456}}
  end
end
