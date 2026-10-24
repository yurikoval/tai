defmodule Tai.VenueAdapters.Binance.UsdMarginFutures do
  alias Tai.VenueAdapters.Binance.{
    Accounts,
    CancelOrder,
    CreateOrder,
    Positions,
    Products,
    StreamSupervisor
  }

  @behaviour Tai.Venues.Adapter
  @market :usd_margin_futures

  def stream_supervisor, do: StreamSupervisor
  def products(venue_id), do: Products.products(venue_id, @market)

  def accounts(venue_id, credential_id, credentials),
    do: Accounts.accounts(venue_id, credential_id, credentials, @market)

  def positions(venue_id, credential_id, credentials),
    do: Positions.positions(venue_id, credential_id, credentials, @market)

  def maker_taker_fees(_venue_id, _credential_id, _credentials), do: {:ok, nil}
  def create_order(order, credentials), do: CreateOrder.create_order(order, credentials, @market)
  def amend_order(_order, _attrs, _credentials), do: {:error, :not_supported}
  def amend_bulk_orders(_orders_with_attrs, _credentials), do: {:error, :not_supported}
  def cancel_order(order, credentials), do: CancelOrder.cancel_order(order, credentials, @market)
end
