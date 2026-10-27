defmodule Tai.VenueAdapters.OkEx.Stream.UpdateOrder do
  @date_format "{ISO:Extended:Z}"

  def apply(
        client_id,
        %{"state" => order_state, "timestamp" => timestamp} = msg,
        received_at,
        state
      ) do
    {:ok, last_received_at} = Tai.Time.monotonic_to_date_time(received_at)

    with {:ok, type} <- transition_type(order_state),
         {:ok, venue_timestamp} <- parse_timestamp(timestamp),
         {:ok, transition_attrs} <- transition_attrs(msg) do
      transition_attrs
      |> Map.put(:last_received_at, last_received_at)
      |> Map.put(:last_venue_timestamp, venue_timestamp)
      |> Map.put(:__type__, type)
      |> then(&Tai.Orders.OrderTransitionWorker.apply(client_id, &1))
    else
      _ -> warn_unhandled(msg, last_received_at, state)
    end
  end

  def apply(_client_id, msg, received_at, state) do
    {:ok, last_received_at} = Tai.Time.monotonic_to_date_time(received_at)
    warn_unhandled(msg, last_received_at, state)
  end

  defp parse_timestamp(timestamp) when is_binary(timestamp),
    do: Timex.parse(timestamp, @date_format)

  defp parse_timestamp(_timestamp), do: {:error, :invalid_timestamp}

  defp warn_unhandled(msg, last_received_at, state) do
    TaiEvents.warning(%Tai.Events.StreamMessageUnhandled{
      venue_id: state.venue,
      msg: msg,
      received_at: last_received_at
    })
  end

  @canceled "-1"
  @pending "0"
  @partially_filled "1"
  @fully_filled "2"

  defp transition_type(s) when s == @canceled, do: {:ok, :cancel}
  defp transition_type(s) when s == @pending, do: {:ok, :open}
  defp transition_type(s) when s == @partially_filled, do: {:ok, :partial_fill}
  defp transition_type(s) when s == @fully_filled, do: {:ok, :fill}
  defp transition_type(_), do: {:error, :invalid_state}

  defp transition_attrs(%{"state" => order_state} = msg) do
    case order_state do
      @canceled ->
        {:ok, %{}}

      state when state in [@pending, @partially_filled] ->
        with {:ok, venue_order_id} <- Map.fetch(msg, "order_id"),
             {:ok, raw_size} <- Map.fetch(msg, "size"),
             {:ok, raw_filled} <- filled(msg),
             {:ok, size} <- Decimal.cast(raw_size),
             {:ok, cumulative_qty} <- Decimal.cast(raw_filled) do
          {:ok,
           %{
             venue_order_id: venue_order_id,
             cumulative_qty: cumulative_qty,
             leaves_qty: Decimal.sub(size, cumulative_qty)
           }}
        else
          _ -> {:error, :invalid_order}
        end

      @fully_filled ->
        with {:ok, venue_order_id} <- Map.fetch(msg, "order_id"),
             {:ok, raw_filled} <- filled(msg),
             {:ok, cumulative_qty} <- Decimal.cast(raw_filled) do
          {:ok, %{venue_order_id: venue_order_id, cumulative_qty: cumulative_qty}}
        else
          _ -> {:error, :invalid_order}
        end
    end
  end

  defp filled(msg) do
    case Map.fetch(msg, "filled_size") do
      {:ok, value} when not is_nil(value) -> {:ok, value}
      _ -> Map.fetch(msg, "filled_qty")
    end
  end
end
