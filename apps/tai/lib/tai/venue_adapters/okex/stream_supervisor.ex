defmodule Tai.VenueAdapters.OkEx.StreamSupervisor do
  use Supervisor

  alias Tai.VenueAdapters.OkEx.Stream.{
    Connection,
    OrderBookSupervisor,
    ProcessAuth,
    PublicConnection,
    ProcessOptionalChannels,
    RouteOrderBooks
  }

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

    system = [
      {RouteOrderBooks, [venue: stream.venue.id, order_books: stream.markets]},
      {ProcessAuth, [venue: stream.venue.id]},
      {ProcessOptionalChannels, [venue: stream.venue.id, markets: stream.markets]},
      {PublicConnection, [endpoint: public_endpoint(), stream: stream]}
    ]

    private_connection =
      if credential do
        [{Connection, [endpoint: private_endpoint(), stream: stream, credential: credential]}]
      else
        []
      end

    (order_book_children ++ system ++ private_connection)
    |> Supervisor.init(strategy: :one_for_one)
  end

  # TODO: Make these configurable
  defp public_endpoint, do: "wss://ws.okx.com/ws/v5/public"
  defp private_endpoint, do: "wss://real.okex.com:8443/ws/v3"

  defp build_order_book_children(markets, quote_depth, broadcast_change_set) do
    Enum.map(markets, fn product ->
      {OrderBookSupervisor,
       [
         product: product,
         quote_depth: quote_depth,
         broadcast_change_set: broadcast_change_set
       ]}
    end)
  end
end
