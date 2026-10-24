defmodule Tai.VenueAdapters.Binance do
  alias Tai.VenueAdapters.Binance.{
    StreamSupervisor,
    Products,
    Accounts,
    MakerTakerFees,
    CreateOrder,
    CancelOrder
  }

  @behaviour Tai.Venues.Adapter

  @market :spot

  def stream_supervisor, do: StreamSupervisor
  def products(venue_id), do: Products.products(venue_id, @market)

  def accounts(venue_id, credential_id, credentials),
    do: Accounts.accounts(venue_id, credential_id, credentials, @market)

  defdelegate maker_taker_fees(venue_id, credential_id, credentials), to: MakerTakerFees
  def positions(_venue_id, _credential_id, _credentials), do: {:error, :not_supported}
  def create_order(order, credentials), do: CreateOrder.create_order(order, credentials, @market)
  def amend_order(_order, _attrs, _credentials), do: {:error, :not_supported}
  def amend_bulk_orders(_orders_with_attrs, _credentials), do: {:error, :not_supported}
  def cancel_order(order, credentials), do: CancelOrder.cancel_order(order, credentials, @market)
end
