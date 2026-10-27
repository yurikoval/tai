defmodule Tai.VenueAdapters.OkEx.ProductsIntegrationTest do
  use Tai.TestSupport.DataCase, async: false
  use ExVCR.Mock, adapter: Tai.Test.ExVCRHackney

  import Tai.TestSupport.Assertions.Event

  defmodule Adapter do
    use Support.StartVenueAdapter

    def products(venue_id), do: Tai.VenueAdapters.OkEx.Products.products(venue_id)
  end

  @venue struct(
           Tai.Venue,
           adapter: Adapter,
           id: :okx_v5_integration,
           credentials: %{},
           accounts: "*",
           products: "btc_usdt",
           market_streams: "btc_usdt",
           timeout: 5_000
         )

  test "hydrates V5 products and proceeds to stream startup" do
    TaiEvents.firehose_subscribe()

    use_cassette "venue_adapters/shared/products/okex/success", match_requests_on: [:query] do
      start_supervised!({Tai.Venues.Start, @venue})

      assert_event(%Tai.Events.HydrateProducts{} = hydration, :info, 5_000)
      assert hydration.venue_id == @venue.id
      assert hydration.total > 0
      assert hydration.filtered == 1

      assert_event(%Tai.Events.VenueStart{venue: :okx_v5_integration}, :info, 5_000)

      assert Process.whereis(Support.StartStreamSupervisor.process_name(@venue.id))
    end
  end
end
