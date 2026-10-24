defmodule Tai.VenueAdapters.Binance.Stream.ProcessOrderBook do
  use GenServer
  alias Tai.Markets.OrderBook
  alias Tai.VenueAdapters.Binance.Market
  alias Tai.VenueAdapters.Binance.Stream.Snapshot

  defmodule State do
    @enforce_keys ~w[product]a
    defstruct [:product, :snapshot_depth, :last_update_id, bridged: false]
  end

  @type product :: Tai.Venues.Product.t()

  @spec start_link(product | keyword) :: GenServer.on_start()
  def start_link(%Tai.Venues.Product{} = product), do: start_link(product: product)

  def start_link(opts) when is_list(opts) do
    product = Keyword.fetch!(opts, :product)
    name = to_name(product.venue_id, product.venue_symbol)

    state = %State{
      product: product,
      snapshot_depth: Keyword.get(opts, :snapshot_depth),
      last_update_id: nil,
      bridged: false
    }

    GenServer.start_link(__MODULE__, state, name: name)
  end

  @spec to_name(Tai.Venue.id(), Tai.Venues.Product.venue_symbol()) :: atom
  def to_name(venue, venue_symbol), do: :"#{__MODULE__}_#{venue}_#{venue_symbol}"

  @impl true
  def init(%State{snapshot_depth: nil} = state), do: {:ok, state}

  def init(state) do
    case sync_snapshot(state) do
      {:ok, state} -> {:ok, state}
      {:error, reason} -> {:stop, reason}
    end
  end

  @impl true
  def handle_cast({:update, %{"U" => first, "u" => last} = msg, received_at}, state) do
    {:noreply, process_sequenced(msg, received_at, first, last, state, true)}
  end

  def handle_cast({:update, msg, received_at}, state) do
    apply_changes(msg, received_at, state)
    {:noreply, state}
  end

  defp process_sequenced(msg, received_at, _first, last, %{last_update_id: nil} = state, _) do
    apply_changes(msg, received_at, state)
    %{state | last_update_id: last, bridged: true}
  end

  defp process_sequenced(_msg, _received_at, _first, last, %{last_update_id: current} = state, _)
       when is_integer(current) and last <= current,
       do: state

  defp process_sequenced(msg, received_at, first, last, state, can_resync) do
    if next_update?(msg, first, last, state) do
      apply_changes(msg, received_at, state)
      %{state | last_update_id: last, bridged: true}
    else
      resync(msg, received_at, first, last, state, can_resync)
    end
  end

  defp next_update?(_msg, first, last, %{bridged: false} = state) do
    current = state.last_update_id

    case Market.from_product(state.product) do
      :spot -> first <= current + 1 && last >= current + 1
      _futures -> first <= current && last >= current
    end
  end

  defp next_update?(msg, first, last, state) do
    case Market.from_product(state.product) do
      :spot -> first <= state.last_update_id + 1 && last >= state.last_update_id + 1
      _futures -> msg["pu"] == state.last_update_id
    end
  end

  defp resync(_msg, _received_at, _first, _last, state, false), do: state
  defp resync(_msg, _received_at, _first, _last, %{snapshot_depth: nil} = state, true), do: state

  defp resync(msg, received_at, first, last, state, true) do
    case sync_snapshot(state) do
      {:ok, synced_state} ->
        process_sequenced(msg, received_at, first, last, synced_state, false)

      {:error, _reason} ->
        state
    end
  end

  defp sync_snapshot(state) do
    with {:ok, change_set, last_update_id} <-
           Snapshot.fetch(state.product, state.snapshot_depth) do
      OrderBook.replace(change_set)
      {:ok, %{state | last_update_id: last_update_id, bridged: false}}
    end
  end

  defp apply_changes(
         %{"E" => event_time, "b" => changed_bids, "a" => changed_asks},
         received_at,
         state
       ) do
    %OrderBook.ChangeSet{
      venue: state.product.venue_id,
      symbol: state.product.symbol,
      last_venue_timestamp: DateTime.from_unix!(event_time, :millisecond),
      last_received_at: received_at,
      changes:
        Enum.concat(normalize_changes(changed_bids, :bid), normalize_changes(changed_asks, :ask))
    }
    |> OrderBook.apply()
  end

  defp normalize_changes(venue_price_points, side) do
    Enum.map(venue_price_points, fn [raw_price, raw_size | _] ->
      price = to_float(raw_price)
      size = to_float(raw_size)

      if size == 0.0, do: {:delete, side, price}, else: {:upsert, side, price, size}
    end)
  end

  defp to_float(value) when is_number(value), do: value / 1
  defp to_float(value), do: value |> Float.parse() |> elem(0)
end
