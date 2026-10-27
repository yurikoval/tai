defmodule Tai.VenueAdapters.OkEx.Stream.ChannelsTest do
  use ExUnit.Case, async: true
  alias Tai.VenueAdapters.OkEx.Stream.Channels

  @product struct(Tai.Venues.Product,
             type: :future,
             venue_symbol: "0G-USD_UM_XPERP-310905"
           )

  test ".depth/1 returns a V5 books subscription argument" do
    assert Channels.depth(@product) == %{
             channel: "books",
             instId: "0G-USD_UM_XPERP-310905"
           }
  end

  test ".trade/1 returns a V5 trades subscription argument" do
    assert Channels.trade(@product) == %{
             channel: "trades",
             instId: "0G-USD_UM_XPERP-310905"
           }
  end

  test ".order/1 remains a V3 private channel string" do
    assert Channels.order(@product) == "futures/order:0G-USD_UM_XPERP-310905"
  end
end
