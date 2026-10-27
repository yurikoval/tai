defmodule Tai.Venues.Start.StreamTest do
  use Tai.TestSupport.DataCase, async: false
  import Tai.TestSupport.Assertions.Event

  defmodule ErrorStreamSupervisor do
    def child_spec(stream) do
      %{id: __MODULE__, start: {__MODULE__, :start_link, [stream]}, type: :supervisor}
    end

    def start_link(_), do: {:error, :stream_failed}
  end

  defmodule RaiseStreamSupervisor do
    def child_spec(stream) do
      %{id: __MODULE__, start: {__MODULE__, :start_link, [stream]}, type: :supervisor}
    end

    def start_link(_) do
      raise "raise_error_for_stream"
    end
  end

  defmodule ErrorStreamAdapter do
    @product struct(Tai.Venues.Product, venue_id: :venue_a, symbol: :btc_usdt)

    def stream_supervisor, do: ErrorStreamSupervisor
    def products(_venue_id), do: {:ok, [@product]}
    def accounts(_venue_id, _credential_id, _credentials), do: {:ok, []}
    def positions(_venue_id, _credential_id, _credentials), do: {:ok, []}
    def maker_taker_fees(_venue_id, _credential_id, _credentials), do: {:ok, nil}
  end

  defmodule RaiseStreamAdapter do
    @product struct(Tai.Venues.Product, venue_id: :venue_a, symbol: :btc_usdt)

    def stream_supervisor, do: RaiseStreamSupervisor
    def products(_venue_id), do: {:ok, [@product]}
    def accounts(_venue_id, _credential_id, _credentials), do: {:ok, []}
    def positions(_venue_id, _credential_id, _credentials), do: {:ok, []}
    def maker_taker_fees(_venue_id, _credential_id, _credentials), do: {:ok, nil}
  end

  @venue struct(
           Tai.Venue,
           adapter: RaiseStreamAdapter,
           id: :venue_a,
           credentials: %{},
           accounts: "*",
           products: "*",
           market_streams: "*",
           timeout: 1_000
         )

  test "records an error when stream startup returns an error" do
    TaiEvents.firehose_subscribe()
    venue = %{@venue | adapter: ErrorStreamAdapter}

    start_supervised!({Tai.Venues.Start, venue})

    assert_event(%Tai.Events.VenueStartError{} = event, :error)
    assert event.venue == venue.id
    assert event.reason == [stream: :stream_failed]
  end

  test "records an error and remains running when stream startup raises" do
    TaiEvents.firehose_subscribe()

    pid = start_supervised!({Tai.Venues.Start, @venue})

    assert_event(%Tai.Events.VenueStartError{} = event, :error)
    assert event.venue == @venue.id
    assert event.reason == [stream: {:exception, RuntimeError}]
    assert Tai.Venues.Start.status(@venue.id) == {:error, event.reason}
    assert Process.alive?(pid)
  end
end
