defmodule Tai.VenueAdapters.Binance.StreamSupervisor do
  use Supervisor

  alias Tai.VenueAdapters.Binance.Market
  alias Tai.VenueAdapters.Binance.Stream.{
    Connection,
    ProcessOptionalChannels,
    ProcessOrderBook,
    RouteOrderBooks
  }

  alias Tai.Markets.OrderBook

  @type stream :: Tai.Venues.Stream.t()
  @type venue_id :: Tai.Venue.id()

  @spec start_link(stream) :: Supervisor.on_start()
  def start_link(stream) do
    name = to_name(stream.venue.id)
    Supervisor.start_link(__MODULE__, stream, name: name)
  end

  @spec to_name(venue_id) :: atom
  def to_name(venue), do: :"#{__MODULE__}_#{venue}"

  def init(stream) do
    credential = stream.venue.credentials |> Map.to_list() |> List.first()

    order_book_children =
      build_order_book_children(
        stream.markets,
        stream.venue.quote_depth,
        stream.venue.broadcast_change_set
      )

    snapshot_depth = Map.get(stream.venue.opts, :snapshot_depth, 50)
    process_order_book_children = build_process_order_book_children(stream.markets, snapshot_depth)
    market = stream.markets |> List.first() |> market()
    endpoint = Map.get(stream.venue.opts, :stream_endpoint, Market.websocket_endpoint(market))

    system = [
      {RouteOrderBooks, [venue_id: stream.venue.id, order_books: stream.markets]},
      {ProcessOptionalChannels, [venue_id: stream.venue.id]},
      {Connection, [endpoint: endpoint, stream: stream, credential: credential]}
    ]

    (order_book_children ++ process_order_book_children ++ system)
    |> Supervisor.init(strategy: :one_for_one)
  end

  defp market(nil), do: :spot
  defp market(product), do: Market.from_product(product)

  defp build_order_book_children(markets, quote_depth, broadcast_change_set) do
    markets
    |> Enum.map(&OrderBook.child_spec(&1, quote_depth, broadcast_change_set))
  end

  defp build_process_order_book_children(markets, snapshot_depth) do
    Enum.map(markets, fn product ->
      %{
        id: ProcessOrderBook.to_name(product.venue_id, product.venue_symbol),
        start:
          {ProcessOrderBook, :start_link,
           [[product: product, snapshot_depth: snapshot_depth]]}
      }
    end)
  end
end
