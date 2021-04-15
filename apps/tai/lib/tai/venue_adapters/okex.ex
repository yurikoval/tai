defmodule Tai.VenueAdapters.OkEx do
  alias Tai.VenueAdapters.OkEx.{
    StreamSupervisor,
    Products,
    Accounts,
    Positions,
    MakerTakerFees,
    CreateOrder,
    CancelOrder,
    AmendOrder
  }

  @behaviour Tai.Venues.Adapter

  def stream_supervisor, do: StreamSupervisor
  defdelegate products(venue_id), to: Products
  def funding_rates(_venue_id), do: {:error, :not_implemented}
  defdelegate accounts(venue_id, credential_id, credentials), to: Accounts
  defdelegate maker_taker_fees(venue_id, credential_id, credentials), to: MakerTakerFees
  defdelegate positions(venue_id, credential_id, credentials), to: Positions
  defdelegate create_order(order, credentials), to: CreateOrder
  defdelegate amend_order(order, attrs, credentials), to: AmendOrder
  def amend_bulk_orders(_orders_with_attrs, _credentials), do: {:error, :not_supported}
  defdelegate cancel_order(order, credentials), to: CancelOrder
end
