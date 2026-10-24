defmodule Tai.VenueAdapters.Binance.CancelOrder do
  alias Tai.Orders.Responses
  alias Tai.VenueAdapters.Binance.{Error, Market}

  def cancel_order(order, credentials, market \\ :spot) do
    venue_credentials = struct!(ExBinance.Credentials, credentials)
    client = Market.rest_client(market)

    params = %{
      symbol: order.venue_product_symbol,
      orderId: order.venue_order_id
    }

    case client.delete(Market.order_path(market), params, venue_credentials) do
      {:ok, %{"orderId" => venue_order_id}} ->
        {:ok,
         %Responses.CancelAccepted{
           id: to_string(venue_order_id),
           received_at: Tai.Time.monotonic_time()
         }}

      {:error, :receive_window} ->
        {:error, {:unhandled, :receive_window}}

      {:error, _} = error ->
        Error.normalize(error)
    end
  end
end
