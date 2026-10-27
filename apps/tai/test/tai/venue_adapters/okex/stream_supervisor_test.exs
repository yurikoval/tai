defmodule Tai.VenueAdapters.OkEx.StreamSupervisorTest do
  use ExUnit.Case, async: false

  alias Tai.Markets.OrderBook
  alias Tai.VenueAdapters.OkEx.Stream.{Connection, ProcessOrderBook, PublicConnection}
  alias Tai.VenueAdapters.OkEx.StreamSupervisor

  test "always starts V5 public streaming and starts legacy private streaming only with credentials" do
    public_ids = child_ids(stream(%{}))
    assert PublicConnection in public_ids
    refute Connection in public_ids

    private_ids = child_ids(stream(%{main: credentials()}))
    assert PublicConnection in private_ids
    assert Connection in private_ids
  end

  test "restarts a book processor when its order book restarts" do
    product =
      struct(Tai.Venues.Product,
        venue_id: :okex_restart_test,
        symbol: :xbtusd,
        venue_symbol: "XBTUSD"
      )

    {:ok, {flags, children}} = StreamSupervisor.init(stream(%{}, [product]))
    book_id = OrderBook.to_name(product.venue_id, product.symbol)
    processor_id = ProcessOrderBook.to_name(product.venue_id, product.venue_symbol)

    coupled_children =
      Enum.filter(children, fn child -> child.id in [book_id, processor_id] end)

    assert flags.strategy == :rest_for_one
    assert Enum.map(coupled_children, & &1.id) == [book_id, processor_id]

    {:ok, supervisor} = Supervisor.start_link(coupled_children, strategy: flags.strategy)
    Process.unlink(supervisor)
    on_exit(fn -> if Process.alive?(supervisor), do: Supervisor.stop(supervisor) end)

    old_book = Process.whereis(book_id)
    old_processor = Process.whereis(processor_id)
    :sys.replace_state(old_processor, &%{&1 | sequence_id: 10})

    Process.exit(old_book, :kill)

    assert wait_for_restart(book_id, old_book)
    new_processor = wait_for_restart(processor_id, old_processor)
    assert %{sequence_id: nil} = :sys.get_state(new_processor)
  end

  defp child_ids(stream) do
    {:ok, {_flags, children}} = StreamSupervisor.init(stream)
    Enum.map(children, & &1.id)
  end

  defp stream(credentials, markets \\ []) do
    venue_id = markets |> List.first() |> then(&if(&1, do: &1.venue_id, else: :okex))

    venue = %Tai.Venue{
      id: venue_id,
      adapter: Tai.VenueAdapters.OkEx,
      channels: [:trades],
      products: "*",
      market_streams: "*",
      accounts: "*",
      credentials: credentials,
      quote_depth: 50,
      timeout: 5_000,
      stream_heartbeat_interval: 5_000,
      stream_heartbeat_timeout: 3_000,
      start_on_boot: false,
      broadcast_change_set: false,
      opts: %{}
    }

    %Tai.Venues.Stream{venue: venue, markets: markets, accounts: [], positions: []}
  end

  defp wait_for_restart(name, old_pid, attempts \\ 50)

  defp wait_for_restart(_name, _old_pid, 0), do: flunk("process did not restart")

  defp wait_for_restart(name, old_pid, attempts) do
    case Process.whereis(name) do
      pid when is_pid(pid) and pid != old_pid ->
        pid

      _ ->
        Process.sleep(10)
        wait_for_restart(name, old_pid, attempts - 1)
    end
  end

  defp credentials do
    %{api_key: "key", api_secret: "secret", api_passphrase: "passphrase"}
  end
end
