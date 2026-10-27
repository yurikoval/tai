defmodule Tai.VenueAdapters.OkEx.Stream.RouteOrderBooks do
  use GenServer
  alias Tai.VenueAdapters.OkEx.Stream.{ProcessOrderBook, PublicConnection}

  defmodule State do
    @type venue_id :: Tai.Venue.id()
    @type venue_symbol :: Tai.Venues.Product.venue_symbol()
    @type store_name :: atom
    @type stores :: %{optional(venue_symbol) => store_name}
    @type t :: %State{venue: venue_id, stores: stores}

    @enforce_keys ~w(venue stores)a
    defstruct ~w(venue stores)a
  end

  @type venue_id :: Tai.Venue.id()
  @type product :: Tai.Venues.Product.t()
  @type state :: State.t()

  @spec start_link(venue: venue_id, order_books: [product]) :: GenServer.on_start()
  def start_link(venue: venue, order_books: order_books) do
    state = %State{venue: venue, stores: build_stores(order_books)}
    GenServer.start_link(__MODULE__, state, name: to_name(venue))
  end

  @spec to_name(venue_id) :: atom
  def to_name(venue), do: :"#{__MODULE__}_#{venue}"

  def reset(venue) do
    if route = Process.whereis(to_name(venue)), do: GenServer.cast(route, :reset)
    :ok
  end

  def reset_and_reconnect(venue) do
    if route = Process.whereis(to_name(venue)), do: GenServer.call(route, :reset)
    PublicConnection.reconnect(venue)
  end

  @impl true
  @spec init(state) :: {:ok, state}
  def init(state), do: {:ok, state}

  @impl true
  def handle_call(:reset, _from, state) do
    reset_stores(state)
    {:reply, :ok, state}
  end

  @impl true
  def handle_cast(:reset, state) do
    reset_stores(state)
    {:noreply, state}
  end

  def handle_cast(
        {%{
           "action" => action,
           "arg" => %{"instId" => venue_symbol},
           "data" => [record]
         } = msg, received_at},
        state
      )
      when action in ["snapshot", "update"] and is_map(record) do
    route(record, action, venue_symbol, msg, received_at, state)
  end

  def handle_cast({msg, received_at}, state) do
    invalidate(msg, received_at, state)
    {:noreply, state}
  end

  defp route(record, action, venue_symbol, msg, received_at, state) do
    case Map.fetch(state.stores, venue_symbol) do
      {:ok, store} ->
        GenServer.cast(store, {normalize_action(action), record, received_at})

      :error ->
        invalidate(msg, received_at, state)
    end

    {:noreply, state}
  end

  defp normalize_action("snapshot"), do: :snapshot
  defp normalize_action("update"), do: :update

  defp build_stores(order_books) do
    Enum.reduce(order_books, %{}, fn product, stores ->
      store = ProcessOrderBook.to_name(product.venue_id, product.venue_symbol)
      Map.put(stores, product.venue_symbol, store)
    end)
  end

  defp invalidate(msg, received_at, state) do
    warn_unhandled(msg, received_at, state)
    reset_stores(state)
    PublicConnection.reconnect(state.venue)
  end

  defp reset_stores(state) do
    Enum.each(state.stores, fn {_venue_symbol, store} -> GenServer.cast(store, :reset) end)
  end

  defp warn_unhandled(msg, received_at, state) do
    TaiEvents.warning(%Tai.Events.StreamMessageUnhandled{
      venue_id: state.venue,
      msg: msg,
      received_at: Tai.Time.monotonic_to_date_time!(received_at)
    })
  end
end
