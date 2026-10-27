defmodule Tai.VenueAdapters.Deribit.StreamSupervisorTest do
  use ExUnit.Case, async: true

  alias Tai.VenueAdapters.Deribit.StreamSupervisor

  @product struct(Tai.Venues.Product,
             venue_id: :deribit,
             symbol: :btc_13nov26_70000_c,
             venue_symbol: "BTC-13NOV26-70000-C"
           )
  @venue struct(Tai.Venue,
           id: :deribit,
           credentials: %{},
           quote_depth: 20,
           broadcast_change_set: false
         )
  @stream struct(Tai.Venues.Stream,
            venue: @venue,
            markets: [@product],
            accounts: [],
            positions: []
          )

  test "builds children from the stream markets" do
    assert {:ok, {_flags, children}} = StreamSupervisor.init(@stream)
    assert length(children) == 4
  end
end
