defmodule Tai.VenueAdapters.OkEx.Stream.Trades do
  import Tai.VenueAdapters.OkEx.Products, only: [to_symbol: 1]
  alias Tai.Utils.Decimal

  def broadcast(
        %{
          "instId" => instrument_id,
          "px" => price,
          "sz" => size,
          "side" => side,
          "ts" => timestamp,
          "tradeId" => venue_trade_id
        },
        venue_id,
        received_at
      ) do
    TaiEvents.info(%Tai.Events.Trade{
      venue_id: venue_id,
      symbol: to_symbol(instrument_id),
      received_at: received_at,
      timestamp: normalize_timestamp(timestamp),
      price: Decimal.cast!(price),
      qty: Decimal.cast!(size),
      taker_side: normalize_side(side),
      venue_trade_id: venue_trade_id
    })
  end

  defp normalize_side("buy"), do: :buy
  defp normalize_side("sell"), do: :sell

  defp normalize_timestamp(timestamp) do
    {milliseconds, ""} = Integer.parse(timestamp)
    DateTime.from_unix!(milliseconds, :millisecond)
  end
end
