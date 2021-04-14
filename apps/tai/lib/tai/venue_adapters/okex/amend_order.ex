defmodule Tai.VenueAdapters.OkEx.AmendOrder do
  @type credentials :: Tai.Venues.Adapter.credentials()
  @type order :: Tai.Trading.Order.t()
  @type attrs :: Tai.Trading.OrderWorker.amend_attrs()
  @type response :: Tai.Trading.OrderResponses.Amend.t()
  @type reason ::
          :timeout
          | :overloaded
          | {:nonce_not_increasing, msg :: String.t()}
          | {:unhandled, term}

  @spec amend_order(order, attrs, credentials) :: {:ok, response} | {:error, reason}
  def amend_order(order, attrs, credentials) do
    {order, attrs, credentials}
    |> send_to_venue()
    |> parse_response(attrs)
  end

  def send_to_venue({order, attrs, credentials}) do
    venue_config = credentials |> to_venue_credentials
    params = to_params(order, attrs)
    mod = order |> module_for()
    {mod.amend_bulk_orders([params], venue_config), order}
  end

  defp module_for(%Tai.Trading.Order{product_type: :future}), do: ExOkex.Futures.Private
  defp module_for(%Tai.Trading.Order{product_type: :swap}), do: ExOkex.Swap.Private
  defp module_for(%Tai.Trading.Order{product_type: :spot}), do: ExOkex.Spot.Private

  defdelegate to_venue_credentials(credentials),
    to: Tai.VenueAdapters.OkEx.Credentials,
    as: :from

  defp to_params(order, attrs) do
    attrs
    |> Enum.reduce(
      %{},
      fn
        {:price, v}, p -> p |> Map.put(:new_price, v)
        {:qty, v}, p -> p |> Map.put(:new_size, v)
        _, p -> p
      end
    )
    |> Map.put(:instrument_id, order.venue_product_symbol)
    |> Map.put(:order_id, order.venue_order_id)
  end

  defp parse_response(
         {{:ok, response}, %Tai.Trading.Order{product_type: :spot} = order},
         new_attrs
       ) do
    response
    |> Map.values()
    |> List.flatten()
    |> parse_spot_response(order, new_attrs)
  end

  defp parse_response({{:ok, response}, _order}, _attrs), do: {:error, {:unandled, response}}
  defp parse_response({{:error, _, 429}, _order}, _attrs), do: {:error, :rate_limited}
  defp parse_response({{:error, error, 400}, _order}, _attrs), do: {:error, {:unhandled, error}}

  @success_code "0"
  defp parse_spot_response(
         [%{"order_id" => venue_order_id, "error_code" => @success_code} | _],
         order,
         new_attrs
       ) do
    received_at = Tai.Time.monotonic_time()

    response = %Tai.Trading.OrderResponses.Amend{
      id: venue_order_id,
      price: new_attrs |> Map.get(:price, order.price),
      status: :open,
      leaves_qty: new_attrs |> Map.get(:qty, order.qty),
      cumulative_qty: order.cumulative_qty,
      venue_timestamp: Timex.now(),
      received_at: received_at
    }

    {:ok, response}
  end

  defp parse_spot_response(
         [%{"error_code" => "30024", "error_message" => reason} | _],
         _order,
         _attrs
       ),
       do: {:error, {:unhandled, reason}}

  defp parse_spot_response([%{"error_code" => "33014"} | _], _order, _attrs),
    do: {:error, :not_found}

  # defp parse_response({:error, :timeout, nil}), do: {:error, :timeout}
  # defp parse_response({:error, :connect_timeout, nil}), do: {:error, :connect_timeout}
  # defp parse_response({:error, :overloaded, _}), do: {:error, :overloaded}
  # defp parse_response({:error, {:nonce_not_increasing, _} = reason, _}), do: {:error, reason}
  # defp parse_response({:error, reason, _}), do: {:error, {:unhandled, reason}}
end
