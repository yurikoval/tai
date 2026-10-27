defmodule Tai.VenueAdapters.OkEx.Stream.ProcessOptionalChannels do
  use GenServer
  alias Tai.VenueAdapters.OkEx.Stream

  defmodule State do
    @type venue_id :: Tai.Venue.id()
    @type markets :: %{optional(String.t()) => Tai.Venues.Product.t()}
    @type t :: %State{venue: venue_id, markets: markets}

    @enforce_keys ~w(venue markets)a
    defstruct ~w(venue markets)a
  end

  @type venue_id :: Tai.Venue.id()
  @type product :: Tai.Venues.Product.t()
  @type state :: State.t()

  @spec start_link(venue: venue_id, markets: [product]) :: GenServer.on_start()
  def start_link(opts) do
    venue = Keyword.fetch!(opts, :venue)
    markets = opts |> Keyword.get(:markets, []) |> Map.new(&{&1.venue_symbol, &1})
    state = %State{venue: venue, markets: markets}
    GenServer.start_link(__MODULE__, state, name: to_name(venue))
  end

  @spec to_name(venue_id) :: atom
  def to_name(venue), do: :"#{__MODULE__}_#{venue}"

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_cast({%{"event" => "subscribe"}, _}, state), do: {:noreply, state}

  @impl true
  def handle_cast(
        {%{"arg" => %{"channel" => "trades", "instId" => instrument_id}, "data" => data},
         received_at},
        state
      )
      when is_binary(instrument_id) and is_list(data) do
    product = Map.get(state.markets, instrument_id)

    Enum.each(
      data,
      &Stream.Trades.broadcast(&1, instrument_id, product, state.venue, received_at)
    )

    {:noreply, state}
  end

  @impl true
  def handle_cast({msg, received_at}, state) do
    TaiEvents.warning(%Tai.Events.StreamMessageUnhandled{
      venue_id: state.venue,
      msg: msg,
      received_at: received_at |> Tai.Time.monotonic_to_date_time!()
    })

    {:noreply, state}
  end
end
