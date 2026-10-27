defmodule Tai.VenueAdapters.OkEx.Stream.ProcessOrderBook do
  use GenServer
  alias Tai.Markets.OrderBook
  alias Tai.VenueAdapters.OkEx.Stream.PublicConnection

  defmodule State do
    @type venue :: Tai.Venue.id()
    @type product_symbol :: Tai.Venues.Product.symbol()
    @type t :: %State{venue: venue, symbol: product_symbol, sequence_id: integer | nil}

    @enforce_keys ~w(venue symbol)a
    defstruct [:venue, :symbol, sequence_id: nil]
  end

  @type venue :: Tai.Venue.id()
  @type venue_symbol :: Tai.Venues.Product.venue_symbol()
  @type product :: Tai.Venues.Product.t()
  @type state :: State.t()

  @spec start_link(product) :: GenServer.on_start()
  def start_link(product) do
    state = %State{venue: product.venue_id, symbol: product.symbol}
    name = to_name(product.venue_id, product.venue_symbol)

    GenServer.start_link(__MODULE__, state, name: name)
  end

  @spec to_name(venue, venue_symbol) :: atom
  def to_name(venue, venue_symbol), do: :"#{__MODULE__}_#{venue}_#{venue_symbol}"

  @spec init(state) :: {:ok, state}
  def init(state), do: {:ok, state}

  def handle_cast({:snapshot, %{"seqId" => sequence_id} = data, received_at}, state)
      when is_integer(sequence_id) do
    case build_change_set(data, received_at, state) do
      {:ok, change_set} ->
        OrderBook.replace(change_set)
        {:noreply, %{state | sequence_id: sequence_id}}

      {:error, reason} ->
        warn(reason, state)
        {:noreply, %{state | sequence_id: nil}}
    end
  end

  def handle_cast({:snapshot, _data, _received_at}, state) do
    warn(:invalid_order_book_message, state)
    {:noreply, %{state | sequence_id: nil}}
  end

  def handle_cast(
        {:update, %{"prevSeqId" => previous_id, "seqId" => sequence_id} = data, received_at},
        %{sequence_id: current_id} = state
      )
      when is_integer(previous_id) and is_integer(sequence_id) and is_integer(current_id) and
             current_id == previous_id do
    case build_change_set(data, received_at, state) do
      {:ok, change_set} ->
        OrderBook.apply(change_set)
        {:noreply, %{state | sequence_id: sequence_id}}

      {:error, reason} ->
        warn(reason, state)
        {:noreply, state}
    end
  end

  def handle_cast({:update, data, _received_at}, state) when is_map(data) do
    gap = %{
      expected: state.sequence_id,
      previous: Map.get(data, "prevSeqId"),
      sequence: Map.get(data, "seqId")
    }

    warn({:sequence_gap, gap}, state)
    PublicConnection.reconnect(state.venue)
    {:noreply, %{state | sequence_id: nil}}
  end

  def handle_cast({_action, _data, _received_at}, state) do
    warn(:invalid_order_book_message, state)
    {:noreply, state}
  end

  defp build_change_set(data, received_at, state) do
    with {:ok, venue_timestamp} <- parse_timestamp(Map.get(data, "ts")),
         {:ok, bids} <- normalize_side(Map.get(data, "bids", []), :bid),
         {:ok, asks} <- normalize_side(Map.get(data, "asks", []), :ask) do
      {:ok,
       %OrderBook.ChangeSet{
         venue: state.venue,
         symbol: state.symbol,
         last_venue_timestamp: venue_timestamp,
         last_received_at: received_at,
         changes: bids ++ asks
       }}
    end
  end

  defp parse_timestamp(timestamp) when is_binary(timestamp) do
    case Integer.parse(timestamp) do
      {milliseconds, ""} -> DateTime.from_unix(milliseconds, :millisecond)
      _ -> {:error, :invalid_timestamp}
    end
  end

  defp parse_timestamp(_timestamp), do: {:error, :invalid_timestamp}

  defp normalize_side(levels, side) when is_list(levels) do
    levels
    |> Enum.reduce_while({:ok, []}, fn
      [raw_price, raw_size, _ignored, _count], {:ok, changes}
      when is_binary(raw_price) and is_binary(raw_size) ->
        with {price, ""} <- Float.parse(raw_price),
             {size, ""} <- Float.parse(raw_size) do
          change =
            if size == 0.0,
              do: {:delete, side, price},
              else: {:upsert, side, price, size}

          {:cont, {:ok, [change | changes]}}
        else
          _ -> {:halt, {:error, :invalid_level}}
        end

      _level, _changes ->
        {:halt, {:error, :invalid_level}}
    end)
    |> case do
      {:ok, changes} -> {:ok, Enum.reverse(changes)}
      {:error, _} = error -> error
    end
  end

  defp normalize_side(_levels, _side), do: {:error, :invalid_levels}

  defp warn(reason, state) do
    TaiEvents.warning(%Tai.Events.StreamError{
      venue_id: state.venue,
      reason: {:order_book, state.symbol, reason}
    })
  end
end
