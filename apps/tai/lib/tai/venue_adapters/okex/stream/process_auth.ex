defmodule Tai.VenueAdapters.OkEx.Stream.ProcessAuth do
  use GenServer
  alias Tai.VenueAdapters.OkEx.{ClientId, Stream}

  defmodule State do
    @type venue_id :: Tai.Venue.id()
    @type t :: %State{venue: atom}

    @enforce_keys ~w[venue]a
    defstruct ~w[venue]a
  end

  @type venue_id :: Tai.Venue.id()
  @type state :: State.t()

  @spec start_link(list) :: GenServer.on_start()
  def start_link(venue: venue) do
    state = %State{venue: venue}
    name = process_name(venue)
    GenServer.start_link(__MODULE__, state, name: name)
  end

  @spec process_name(venue_id) :: atom
  def process_name(venue), do: :"#{__MODULE__}_#{venue}"

  @impl true
  def init(state) do
    {:ok, state}
  end

  @product_types ["swap/order", "futures/order", "spot/order"]

  @impl true
  def handle_cast(
        {%{"table" => table, "data" => orders}, received_at},
        state
      )
      when table in @product_types and is_list(orders) do
    Enum.each(orders, &process_order(&1, received_at, state))
    {:noreply, state}
  end

  @impl true
  def handle_cast({msg, received_at}, state) do
    warn_unhandled(msg, received_at, state)
    {:noreply, state}
  end

  defp process_order(%{"client_oid" => venue_client_id} = msg, received_at, state)
       when is_binary(venue_client_id) do
    case decode_client_id(venue_client_id) do
      {:ok, client_id} ->
        case Stream.UpdateOrder.apply(client_id, msg, received_at, state) do
          {:error, reason} -> warn_update_error(client_id, reason, state)
          _result -> :ok
        end

      :error ->
        warn_unhandled(msg, received_at, state)
    end
  end

  defp process_order(msg, received_at, state), do: warn_unhandled(msg, received_at, state)

  defp decode_client_id(venue_client_id) do
    try do
      {:ok, ClientId.from_base32(venue_client_id)}
    rescue
      _ in [ArgumentError, MatchError] -> :error
    end
  end

  defp warn_update_error(client_id, reason, state) do
    TaiEvents.warning(%Tai.Events.StreamError{
      venue_id: state.venue,
      reason: {:order_update, client_id, reason}
    })
  end

  defp warn_unhandled(msg, received_at, state) do
    TaiEvents.warning(%Tai.Events.StreamMessageUnhandled{
      venue_id: state.venue,
      msg: msg,
      received_at: Tai.Time.monotonic_to_date_time!(received_at)
    })
  end
end
