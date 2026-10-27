defmodule Tai.VenueAdapters.OkEx.Stream.Trades do
  def broadcast(msg, envelope_instrument_id, product, venue_id, received_at) do
    case build_event(msg, envelope_instrument_id, product, venue_id, received_at) do
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
         envelope_instrument_id,
         %Tai.Venues.Product{venue_symbol: instrument_id, symbol: symbol},
         venue_id,
         received_at
       )
       when instrument_id == envelope_instrument_id do
    with true <- nonempty?(instrument_id),
         true <- nonempty?(venue_trade_id),
         {:ok, price} <- positive_decimal(price),
         {:ok, size} <- positive_decimal(size),
         {:ok, side} <- normalize_side(side),
         {:ok, timestamp} <- normalize_timestamp(timestamp) do
      {:ok,
       %Tai.Events.Trade{
         venue_id: venue_id,
         symbol: symbol,
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

  defp build_event(_, _, _, _, _), do: :error

  defp nonempty?(value), do: is_binary(value) and String.trim(value) != ""

  defp positive_decimal(value) do
    with {:ok, decimal} <- Decimal.cast(value),
         false <- Decimal.nan?(decimal),
         false <- Decimal.inf?(decimal),
         true <- Decimal.positive?(decimal) do
      {:ok, decimal}
    else
      _ -> :error
    end
  end

  defp normalize_side("buy"), do: {:ok, :buy}
  defp normalize_side("sell"), do: {:ok, :sell}
  defp normalize_side(_), do: :error

  defp normalize_timestamp(timestamp) when is_binary(timestamp) do
    case Integer.parse(timestamp) do
      {milliseconds, ""} when milliseconds >= 0 -> DateTime.from_unix(milliseconds, :millisecond)
      _ -> :error
    end
  end

  defp normalize_timestamp(_), do: :error
end
