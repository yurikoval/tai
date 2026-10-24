defmodule Tai.VenueAdapters.Binance.CreateOrder do
  alias Tai.Orders.Responses
  alias Tai.VenueAdapters.Binance.{Error, Market}

  def create_order(%Tai.Orders.Order{type: :limit} = order, credentials, market \\ :spot) do
    venue_credentials = struct!(ExBinance.Credentials, credentials)
    client = Market.rest_client(market)
    path = Market.order_path(market)

    case client.post(path, build_params(order, market), venue_credentials) do
      {:ok, response} -> parse_response(response)
      {:error, _} = error -> normalize_error(error)
    end
  end

  defp build_params(order, :spot) do
    %{
      symbol: order.venue_product_symbol,
      side: venue_side(order.side),
      type: if(order.post_only, do: "LIMIT_MAKER", else: "LIMIT"),
      quantity: decimal_string(order.qty),
      price: decimal_string(order.price),
      newClientOrderId: order.client_id
    }
    |> maybe_put_time_in_force(order)
  end

  defp build_params(order, _market) do
    %{
      symbol: order.venue_product_symbol,
      side: venue_side(order.side),
      type: "LIMIT",
      quantity: decimal_string(order.qty),
      price: decimal_string(order.price),
      timeInForce: futures_time_in_force(order),
      newClientOrderId: order.client_id
    }
    |> maybe_reduce_only(order)
  end

  defp maybe_put_time_in_force(params, %{post_only: true}), do: params

  defp maybe_put_time_in_force(params, order),
    do: Map.put(params, :timeInForce, time_in_force(order))

  defp maybe_reduce_only(params, %{close: true}), do: Map.put(params, :reduceOnly, "true")
  defp maybe_reduce_only(params, _order), do: params

  defp futures_time_in_force(%{post_only: true}), do: "GTX"
  defp futures_time_in_force(order), do: time_in_force(order)

  defp time_in_force(%{time_in_force: :gtc}), do: "GTC"
  defp time_in_force(%{time_in_force: :fok}), do: "FOK"
  defp time_in_force(%{time_in_force: :ioc}), do: "IOC"

  defp venue_side(side), do: side |> Atom.to_string() |> String.upcase()
  defp decimal_string(value), do: Decimal.to_string(value, :normal)

  defp normalize_error({:error, :receive_window}), do: {:error, {:unhandled, :receive_window}}
  defp normalize_error(error), do: Error.normalize(error)

  defp parse_response(%{"orderId" => venue_order_id} = response) do
    venue_timestamp =
      case response["transactTime"] || response["updateTime"] do
        nil -> nil
        timestamp -> DateTime.from_unix!(timestamp, :millisecond)
      end

    {:ok,
     %Responses.CreateAccepted{
       id: to_string(venue_order_id),
       venue_timestamp: venue_timestamp,
       received_at: Tai.Time.monotonic_time()
     }}
  end
end
