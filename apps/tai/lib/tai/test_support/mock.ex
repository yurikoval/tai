defmodule Tai.TestSupport.Mock do
  @type location :: Tai.Markets.Location.t()
  @type venue :: Tai.Venue.t()
  @type product :: Tai.Venues.Product.t()
  @type fee_info :: Tai.Venues.FeeInfo.t()
  @type venue_id :: Tai.Venue.id()
  @type credential_id :: Tai.Venue.credential_id()
  @type asset :: Tai.Venues.Account.asset()
  @type balance :: Decimal.t() | number | String.t()
  @type record :: Stored.Backend.record()
  @type record_key :: Stored.Backend.key()

  @spec mock_venue(venue | map | [{atom, term}]) :: {:ok, {key :: term, resource :: struct}}
  def mock_venue(%Tai.Venue{} = venue) do
    venue
    |> Tai.Venues.VenueStore.put()
  end

  def mock_venue(attrs) do
    Tai.Venue
    |> struct(attrs)
    |> mock_venue
  end

  @spec mock_product(product | map | [{atom, term}]) :: :ok
  def mock_product(%Tai.Venues.Product{} = product) do
    product
    |> Tai.Venues.ProductStore.upsert()
  end

  def mock_product(attrs) when is_map(attrs) or is_list(attrs) do
    Tai.Venues.Product
    |> struct(attrs)
    |> mock_product
  end

  @spec mock_fee_info(fee_info | map) :: :ok
  def mock_fee_info(%Tai.Venues.FeeInfo{} = fee_info) do
    fee_info
    |> Tai.Venues.FeeStore.upsert()
  end

  def mock_fee_info(attrs) when is_map(attrs) do
    Tai.Venues.FeeInfo
    |> struct(attrs)
    |> Tai.Venues.FeeStore.upsert()
  end

  @spec mock_account(venue_id, credential_id, asset, balance, balance) ::
          {:ok, {record_key, record}}
  def mock_account(venue_id, credential_id, asset, free, locked) do
    {:ok, free} = Decimal.cast(free)
    {:ok, locked} = Decimal.cast(locked)
    equity = Decimal.add(free, locked)

    %Tai.Venues.Account{
      venue_id: venue_id,
      credential_id: credential_id,
      type: "default",
      asset: asset,
      equity: equity,
      free: free,
      locked: locked
    }
    |> Tai.Venues.AccountStore.put()
  end

  @spec push_market_data_snapshot(location :: location, bids :: map, asks :: map) :: no_return
  def push_market_data_snapshot(location, bids, asks) do
    :ok =
      location.venue_id
      |> whereis_stream_connection
      |> send_json_msg(%{
        type: :snapshot,
        symbol: location.product_symbol,
        bids: bids,
        asks: asks
      })
  end

  @spec push_order_update(venue_id, map) :: no_return
  def push_order_update(venue_id, attrs) do
    :ok =
      venue_id
      |> whereis_stream_connection()
      |> send_json_msg(attrs)
  end

  defp whereis_stream_connection(venue_id) do
    venue_id
    |> Tai.VenueAdapters.Mock.Stream.Connection.to_name()
    |> Process.whereis()
  end

  defp send_json_msg(pid, msg) do
    Tai.WebSocket.send_json_msg(pid, msg)
  end
end
