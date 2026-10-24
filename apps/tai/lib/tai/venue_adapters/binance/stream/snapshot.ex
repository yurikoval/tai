defmodule Tai.VenueAdapters.Binance.Stream.Snapshot do
  alias Tai.Markets.OrderBook
  alias Tai.VenueAdapters.Binance.Market

  @type product :: Tai.Venues.Product.t()
  @type change_set :: OrderBook.ChangeSet.t()

  @spec fetch(product, pos_integer) :: {:ok, change_set, non_neg_integer} | {:error, term}
  def fetch(product, depth) do
    market = Market.from_product(product)
    client = Market.rest_client(market)
    params = %{symbol: product.venue_symbol, limit: depth}

    with {:ok, %{"bids" => bids, "asks" => asks, "lastUpdateId" => last_update_id}} <-
           client.get(Market.depth_path(market), params) do
      change_set = %OrderBook.ChangeSet{
        venue: product.venue_id,
        symbol: product.symbol,
        last_received_at: Tai.Time.monotonic_time(),
        changes: Enum.concat(normalize_changes(bids, :bid), normalize_changes(asks, :ask))
      }

      {:ok, change_set, last_update_id}
    end
  end

  defp normalize_changes(venue_price_points, side) do
    Enum.map(venue_price_points, fn [raw_price, raw_size | _] ->
      {:upsert, side, to_float(raw_price), to_float(raw_size)}
    end)
  end

  defp to_float(value) when is_number(value), do: value / 1
  defp to_float(value), do: value |> Float.parse() |> elem(0)
end
