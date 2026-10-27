defmodule Tai.VenueAdapters.OkEx.Stream.OrderBookSupervisor do
  use Supervisor

  alias Tai.Markets.OrderBook
  alias Tai.VenueAdapters.OkEx.Stream.ProcessOrderBook

  @type product :: Tai.Venues.Product.t()
  @type quote_depth :: pos_integer

  @spec child_spec(product: product, quote_depth: quote_depth, broadcast_change_set: boolean) ::
          Supervisor.child_spec()
  def child_spec(opts) do
    product = Keyword.fetch!(opts, :product)

    %{
      id: to_name(product.venue_id, product.venue_symbol),
      start: {__MODULE__, :start_link, [opts]},
      type: :supervisor
    }
  end

  @spec start_link(product: product, quote_depth: quote_depth, broadcast_change_set: boolean) ::
          Supervisor.on_start()
  def start_link(opts) do
    product = Keyword.fetch!(opts, :product)
    name = to_name(product.venue_id, product.venue_symbol)
    Supervisor.start_link(__MODULE__, opts, name: name)
  end

  @spec to_name(Tai.Venue.id(), Tai.Venues.Product.venue_symbol()) :: atom
  def to_name(venue, venue_symbol), do: :"#{__MODULE__}_#{venue}_#{venue_symbol}"

  @impl true
  def init(opts) do
    product = Keyword.fetch!(opts, :product)
    quote_depth = Keyword.fetch!(opts, :quote_depth)
    broadcast_change_set = Keyword.fetch!(opts, :broadcast_change_set)

    children = [
      OrderBook.child_spec(product, quote_depth, broadcast_change_set),
      {ProcessOrderBook, product}
    ]

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
