defmodule Tai.VenueAdapters.OkEx.Stream.ConnectionTest do
  use ExUnit.Case, async: true
  import Tai.TestSupport.Assertions.Event

  alias Tai.VenueAdapters.OkEx.Stream.Connection
  alias Tai.Venues.Streams.ConnectionAdapter

  @product struct(Tai.Venues.Product,
             type: :future,
             venue_symbol: "0G-USD_UM_XPERP-310905"
           )

  test "preserves the legacy private login payload" do
    assert {:reply, {:text, payload}, _state} = Connection.subscribe(:login, state())

    assert %{"op" => "login", "args" => ["key", "passphrase", _timestamp, _signature]} =
             Jason.decode!(payload)
  end

  test "preserves the legacy private orders subscription" do
    assert {:reply, {:text, payload}, _state} = Connection.subscribe(:orders, state())

    assert Jason.decode!(payload) == %{
             "op" => "subscribe",
             "args" => ["futures/order:0G-USD_UM_XPERP-310905"]
           }
  end

  test "routes legacy private order messages to the auth processor" do
    state = state()
    msg = %{"table" => "futures/order", "data" => []}

    assert {:ok, ^state} = Connection.on_msg(msg, 123, state)
    assert_receive {:"$gen_cast", {^msg, 123}}
  end

  test "logs and ignores malformed compressed frames" do
    TaiEvents.firehose_subscribe()
    state = state()

    assert {:ok, ^state} = Connection.handle_frame({:binary, <<0>>}, state)
    assert_event(%Tai.Events.StreamError{}, :warning)

    invalid_json = :zlib.zip("not-json")
    assert {:ok, ^state} = Connection.handle_frame({:binary, invalid_json}, state)
    assert_event(%Tai.Events.StreamError{}, :warning)
  end

  defp state do
    %ConnectionAdapter.State{
      venue: :okex,
      routes: %{auth: self()},
      channels: [],
      credential: {:main, %{api_key: "key", api_secret: "secret", api_passphrase: "passphrase"}},
      markets: [@product],
      quote_depth: 20,
      heartbeat_interval: 5_000,
      heartbeat_timeout: 3_000,
      compression: :unzip,
      opts: %{}
    }
  end
end
