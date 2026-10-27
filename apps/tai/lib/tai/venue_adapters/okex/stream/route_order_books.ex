defmodule Tai.VenueAdapters.OkEx.Stream.RouteOrderBooks do
  use GenServer
  alias Tai.VenueAdapters.OkEx.Stream.ProcessOrderBook

  defmodule State do
    @type venue_id :: Tai.Venue.id()
    @type venue_symbol :: Tai.Venues.Product.symbol()
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

  @spec init(state) :: {:ok, state}
  def init(state), do: {:ok, state}

  def handle_cast(
        {%{
           "action" => "snapshot",
           "arg" => %{"instId" => venue_symbol},
           "data" => data
         } = msg, received_at},
        state
      )
      when is_list(data) do
    route(data, :snapshot, venue_symbol, msg, received_at, state)
  end

  def handle_cast(
        {%{
           "action" => "update",
           "arg" => %{"instId" => venue_symbol},
           "data" => data
         } = msg, received_at},
        state
      )
      when is_list(data) do
    route(data, :update, venue_symbol, msg, received_at, state)
  end

  def handle_cast({msg, received_at}, state) do
    warn_unhandled(msg, received_at, state)
    {:noreply, state}
  end

  defp route(data, action, venue_symbol, msg, received_at, state) do
    case Map.fetch(state.stores, venue_symbol) do
      {:ok, store} ->
        Enum.each(data, &GenServer.cast(store, {action, &1, received_at}))

      :error ->
        warn_unhandled(msg, received_at, state)
    end

    {:noreply, state}
  end

  defp build_stores(order_books) do
    Enum.reduce(order_books, %{}, fn product, stores ->
      store = ProcessOrderBook.to_name(product.venue_id, product.venue_symbol)
      Map.put(stores, product.venue_symbol, store)
    end)
  end

  defp warn_unhandled(msg, received_at, state) do
    TaiEvents.warning(%Tai.Events.StreamMessageUnhandled{
      venue_id: state.venue,
      msg: msg,
      received_at: received_at(received_at)
    })
  end

  defp received_at(%DateTime{} = received_at), do: received_at
  defp received_at(received_at), do: Tai.Time.monotonic_to_date_time!(received_at)
end
