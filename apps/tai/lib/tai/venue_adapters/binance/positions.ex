defmodule Tai.VenueAdapters.Binance.Positions do
  alias Tai.VenueAdapters.Binance.{Error, Market, Products}

  def positions(venue_id, credential_id, credentials, market) do
    venue_credentials = struct!(ExBinance.Credentials, credentials)
    client = Market.rest_client(market)

    case client.get(Market.account_path(market), %{}, venue_credentials) do
      {:ok, %{"positions" => positions}} ->
        if Enum.any?(positions, &(&1["positionSide"] in ["LONG", "SHORT"])) do
          {:error, {:unhandled, :hedge_mode_not_supported}}
        else
          {:ok,
           positions
           |> Enum.map(&build(&1, venue_id, credential_id, market))
           |> Enum.reject(&is_nil/1)}
        end

      {:error, _} = error ->
        Error.normalize(error)
    end
  end

  defp build(%{"positionAmt" => raw_qty} = position, venue_id, credential_id, market) do
    qty = decimal(raw_qty)

    if Decimal.equal?(qty, 0) do
      nil
    else
      %Tai.Trading.Position{
        venue_id: venue_id,
        credential_id: credential_id,
        product_symbol: Products.to_symbol(Map.fetch!(position, "symbol"), market),
        side: side(position, qty),
        qty: Decimal.abs(qty),
        entry_price: decimal(Map.fetch!(position, "entryPrice")),
        leverage: decimal(position["leverage"] || 1),
        margin_mode: margin_mode(position)
      }
    end
  end

  defp side(_position, qty) do
    case Decimal.compare(qty, 0) do
      :lt -> :short
      _ -> :long
    end
  end

  defp margin_mode(%{"isolated" => value}) when value in [true, "true"], do: :fixed
  defp margin_mode(%{"marginType" => "isolated"}), do: :fixed
  defp margin_mode(_), do: :crossed

  defp decimal(value), do: value |> to_string() |> Decimal.new() |> Decimal.normalize()
end
