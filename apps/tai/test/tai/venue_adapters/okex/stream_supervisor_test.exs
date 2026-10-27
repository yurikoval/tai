defmodule Tai.VenueAdapters.OkEx.StreamSupervisorTest do
  use ExUnit.Case, async: true

  alias Tai.VenueAdapters.OkEx.Stream.{Connection, PublicConnection}
  alias Tai.VenueAdapters.OkEx.StreamSupervisor

  test "always starts V5 public streaming and starts legacy private streaming only with credentials" do
    public_ids = child_ids(stream(%{}))
    assert PublicConnection in public_ids
    refute Connection in public_ids

    private_ids = child_ids(stream(%{main: credentials()}))
    assert PublicConnection in private_ids
    assert Connection in private_ids
  end

  defp child_ids(stream) do
    {:ok, {_flags, children}} = StreamSupervisor.init(stream)
    Enum.map(children, & &1.id)
  end

  defp stream(credentials) do
    venue = %Tai.Venue{
      id: :okex,
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

    %Tai.Venues.Stream{venue: venue, markets: [], accounts: [], positions: []}
  end

  defp credentials do
    %{api_key: "key", api_secret: "secret", api_passphrase: "passphrase"}
  end
end
