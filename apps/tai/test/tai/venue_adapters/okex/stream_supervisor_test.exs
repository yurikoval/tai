defmodule Tai.VenueAdapters.OkEx.StreamSupervisorTest do
  use ExUnit.Case, async: false

  alias Tai.Markets.OrderBook

  alias Tai.VenueAdapters.OkEx.Stream.{
    Connection,
    OrderBookSupervisor,
    ProcessOrderBook,
    PublicConnection
  }

  alias Tai.VenueAdapters.OkEx.StreamSupervisor

  test "always starts V5 public streaming and starts legacy private streaming only with credentials" do
    public_ids = child_ids(stream(%{}))
    assert PublicConnection in public_ids
    refute Connection in public_ids

    private_ids = child_ids(stream(%{main: credentials()}))
    assert PublicConnection in private_ids
    assert Connection in private_ids
  end

  test "localizes book lifecycle recovery without restarting connections" do
    product =
      struct(Tai.Venues.Product,
        venue_id: :okex_restart_test,
        symbol: :xbtusd,
        venue_symbol: "XBTUSD"
      )

    {:ok, {flags, children}} = StreamSupervisor.init(stream(%{}, [product]))
    pair_id = OrderBookSupervisor.to_name(product.venue_id, product.venue_symbol)
    pair_child = Enum.find(children, &(&1.id == pair_id))

    assert flags.strategy == :one_for_one
    assert pair_child

    root_children = [
      pair_child,
      worker_child(PublicConnection),
      worker_child(Connection)
    ]

    {:ok, supervisor} = Supervisor.start_link(root_children, strategy: flags.strategy)
    Process.unlink(supervisor)
    on_exit(fn -> if Process.alive?(supervisor), do: Supervisor.stop(supervisor) end)

    book_id = OrderBook.to_name(product.venue_id, product.symbol)
    processor_id = ProcessOrderBook.to_name(product.venue_id, product.venue_symbol)
    private_connection = child_pid(supervisor, Connection)
    public_connection = child_pid(supervisor, PublicConnection)
    old_book = Process.whereis(book_id)
    old_processor = Process.whereis(processor_id)
    :sys.replace_state(old_processor, &%{&1 | sequence_id: 10})

    Process.exit(old_book, :kill)

    assert wait_for_restart(book_id, old_book)
    new_processor = wait_for_restart(processor_id, old_processor)
    assert %{sequence_id: nil} = :sys.get_state(new_processor)
    assert child_pid(supervisor, Connection) == private_connection

    Process.exit(public_connection, :kill)

    new_public_connection =
      wait_for_child_restart(supervisor, PublicConnection, public_connection)

    assert child_pid(supervisor, Connection) == private_connection

    Process.exit(private_connection, :kill)

    assert wait_for_child_restart(supervisor, Connection, private_connection)
    assert child_pid(supervisor, PublicConnection) == new_public_connection
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

  defp worker_child(id) do
    %{
      id: id,
      start: {Agent, :start_link, [fn -> :ok end]}
    }
  end

  defp child_pid(supervisor, id) do
    Enum.find_value(Supervisor.which_children(supervisor), fn
      {^id, pid, :worker, _modules} -> pid
      _child -> nil
    end)
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

  defp wait_for_child_restart(supervisor, id, old_pid, attempts \\ 50)

  defp wait_for_child_restart(_supervisor, _id, _old_pid, 0),
    do: flunk("child did not restart")

  defp wait_for_child_restart(supervisor, id, old_pid, attempts) do
    case child_pid(supervisor, id) do
      pid when is_pid(pid) and pid != old_pid ->
        pid

      _ ->
        Process.sleep(10)
        wait_for_child_restart(supervisor, id, old_pid, attempts - 1)
    end
  end

  defp credentials do
    %{api_key: "key", api_secret: "secret", api_passphrase: "passphrase"}
  end
end
