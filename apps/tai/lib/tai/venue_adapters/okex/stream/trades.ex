defmodule Tai.VenueAdapters.OkEx.Stream.Trades do
  import Tai.VenueAdapters.OkEx.Products, only: [to_symbol: 1]

  def broadcast(msg, venue_id, received_at) do
    case build_event(msg, venue_id, received_at) do
      {:ok, event} ->
        TaiEvents.info(event)

      :error ->
        TaiEvents.warning(%Tai.Events.StreamMessageUnhandled{
          venue_id: venue_id,
          msg: msg,
          received_at: Tai.Time.monotonic_to_date_time!(received_at)
        })
    end
  end

  defp build_event(
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
       )
       when is_binary(instrument_id) and is_binary(venue_trade_id) do
    with {:ok, price} <- Decimal.cast(price),
         {:ok, size} <- Decimal.cast(size),
         {:ok, side} <- normalize_side(side),
         {:ok, timestamp} <- normalize_timestamp(timestamp) do
      {:ok,
       %Tai.Events.Trade{
         venue_id: venue_id,
         symbol: to_symbol(instrument_id),
         received_at: received_at,
         timestamp: timestamp,
         price: price,
         qty: size,
         taker_side: side,
         venue_trade_id: venue_trade_id
       }}
    else
      _ -> :error
    end
  end

  defp build_event(_, _, _), do: :error

  defp normalize_side("buy"), do: {:ok, :buy}
  defp normalize_side("sell"), do: {:ok, :sell}
  defp normalize_side(_), do: :error

  defp normalize_timestamp(timestamp) when is_binary(timestamp) do
    case Integer.parse(timestamp) do
      {milliseconds, ""} -> DateTime.from_unix(milliseconds, :millisecond)
      _ -> :error
    end
  end

  defp normalize_timestamp(_), do: :error
end
