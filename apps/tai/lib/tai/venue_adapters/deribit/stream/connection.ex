defmodule Tai.VenueAdapters.Deribit.Stream.Connection do
  use WebSockex
  alias Tai.VenueAdapters.Deribit.Stream

  defmodule State do
    @type product :: Tai.Venues.Product.t()
    @type account :: Tai.Venues.Account.t()
    @type venue :: Tai.Venue.id()
    @type credential_id :: Tai.Venue.credential_id()
    @type channel_name :: atom
    @type portfolio_channel :: String.t()
    @type route :: :order_books
    @type jsonrpc_id :: non_neg_integer
    @type t :: %State{
            venue: venue,
            routes: %{required(route) => atom},
            channels: [channel_name],
            credential: {credential_id, map} | nil,
            products: [product],
            account_channels: %{optional(portfolio_channel) => account},
            quote_depth: pos_integer,
            opts: map,
            last_heartbeat: pos_integer,
            jsonrpc_id: jsonrpc_id,
            jsonrpc_requests: %{
              optional(jsonrpc_id) => pos_integer
            }
          }

    @enforce_keys ~w(
      venue
      routes
      channels
      products
      account_channels
      quote_depth
      opts
      jsonrpc_id
      jsonrpc_requests
    )a
    defstruct ~w(
      venue routes
      channels
      credential
      products
      account_channels
      quote_depth
      opts
      last_heartbeat
      jsonrpc_id
      jsonrpc_requests
    )a
  end

  @type stream :: Tai.Venues.Stream.t()
  @type venue_id :: Tai.Venue.id()
  @type credential_id :: Tai.Venue.credential_id()
  @type credential :: Tai.Venue.credential()
  @type venue_msg :: map

  @spec start_link(
          endpoint: String.t(),
          stream: stream,
          credential: {credential_id, credential} | nil
        ) :: {:ok, pid} | {:error, term}
  def start_link(endpoint: endpoint, stream: stream, credential: credential) do
    routes = %{
      order_books: stream.venue.id |> Stream.RouteOrderBooks.to_name()
    }

    state = %State{
      venue: stream.venue.id,
      routes: routes,
      channels: stream.venue.channels,
      credential: credential,
      products: stream.products,
      account_channels: account_channels(stream.accounts),
      quote_depth: stream.venue.quote_depth,
      opts: stream.venue.opts,
      jsonrpc_id: 1,
      jsonrpc_requests: %{}
    }

    name = to_name(stream.venue.id)
    headers = []
    WebSockex.start_link(endpoint, __MODULE__, state, name: name, extra_headers: headers)
  end

  @spec to_name(venue_id) :: atom
  def to_name(venue), do: :"#{__MODULE__}_#{venue}"

  def handle_connect(_conn, state) do
    TaiEvents.info(%Tai.Events.StreamConnect{venue: state.venue})
    send(self(), :init_subscriptions)
    {:ok, state}
  end

  def handle_disconnect(conn_status, state) do
    TaiEvents.warn(%Tai.Events.StreamDisconnect{
      venue: state.venue,
      reason: conn_status.reason
    })

    {:ok, state}
  end

  def terminate(close_reason, state) do
    TaiEvents.warn(%Tai.Events.StreamTerminate{venue: state.venue, reason: close_reason})
  end

  def handle_info(:init_subscriptions, state) do
    send(self(), {:subscribe, :heartbeat})
    send(self(), {:subscribe, :depth})
    if state.credential, do: send(self(), {:subscribe, :authenticate})
    {:ok, state}
  end

  @heartbeat_interval_s 10
  def handle_info({:subscribe, :heartbeat}, state) do
    msg =
      %{
        method: "public/set_heartbeat",
        id: state.jsonrpc_id,
        params: %{
          interval: @heartbeat_interval_s
        }
      }
      |> Jason.encode!()

    state =
      state
      |> add_jsonrpc_request()
      |> Map.put(:last_heartbeat, heartbeat_timestamp())

    {:reply, {:text, msg}, state}
  end

  def handle_info({:subscribe, :depth}, state) do
    channels = state.products |> Enum.map(&"book.#{&1.venue_symbol}.none.20.100ms")

    msg =
      %{
        method: "public/subscribe",
        id: state.jsonrpc_id,
        params: %{
          channels: channels
        }
      }
      |> Jason.encode!()

    state = state |> add_jsonrpc_request()

    {:reply, {:text, msg}, state}
  end

  def handle_info({:subscribe, :authenticate}, state) do
    data = ""
    timestamp = ExDeribit.Auth.timestamp()
    nonce = ExDeribit.Auth.nonce()
    {_, credential} = state.credential
    signature = ExDeribit.Auth.sign(credential.client_secret, timestamp, nonce, data)

    msg =
      %{
        method: "public/auth",
        id: state.jsonrpc_id,
        params: %{
          grant_type: "client_signature",
          client_id: credential.client_id,
          timestamp: timestamp,
          signature: signature,
          nonce: nonce,
          data: data
        }
      }
      |> Jason.encode!()

    state = state |> add_jsonrpc_request()

    {:reply, {:text, msg}, state}
  end

  def handle_frame({:text, msg}, state) do
    msg
    |> Jason.decode!()
    |> handle_msg(state)
  end

  def handle_frame(_frame, state), do: {:ok, state}

  defp handle_msg(
         %{"id" => id, "result" => %{"access_token" => access_token}},
         state
       ) do
    msg =
      %{
        method: "private/subscribe",
        id: state.jsonrpc_id,
        params: %{
          access_token: access_token,
          channels: state.account_channels |> Map.keys()
        }
      }
      |> Jason.encode!()

    state =
      state
      |> delete_jsonrpc_request(id)
      |> add_jsonrpc_request()

    {:reply, {:text, msg}, state}
  end

  defp handle_msg(%{"id" => id, "result" => _}, state) do
    state = delete_jsonrpc_request(state, id)
    {:ok, state}
  end

  defp handle_msg(
         %{
           "method" => "subscription",
           "params" => %{"channel" => "book." <> _channel}
         } = msg,
         state
       ) do
    msg |> forward(:order_books, state)
    {:ok, state}
  end

  @heartbeat_interval_timeout_ms 12_000
  defp handle_msg(
         %{
           "method" => "heartbeat",
           "params" => %{"type" => "heartbeat"}
         },
         state
       ) do
    now = heartbeat_timestamp()
    diff = now - state.last_heartbeat
    state = Map.put(state, :last_heartbeat, now)

    if diff > @heartbeat_interval_timeout_ms do
      {:close, {1000, "heartbeat timeout"}, state}
    else
      {:ok, state}
    end
  end

  defp handle_msg(
         %{
           "method" => "heartbeat",
           "params" => %{"type" => "test_request"}
         },
         state
       ) do
    msg =
      %{method: "public/test", id: state.jsonrpc_id}
      |> Jason.encode!()

    state = state |> add_jsonrpc_request()

    {:reply, {:text, msg}, state}
  end

  defp handle_msg(
         %{
           "params" => %{
             "data" => %{"equity" => venue_equity},
             "channel" => channel
           },
           "method" => "subscription"
         },
         state
       ) do
    {:ok, equity} = Decimal.cast(venue_equity)
    account = state.account_channels |> Map.fetch!(channel)
    account = %{account | equity: equity, locked: equity}
    {:ok, _} = Tai.Venues.AccountStore.put(account)

    {:ok, state}
  end

  defp handle_msg(_msg, state) do
    {:ok, state}
  end

  defp heartbeat_timestamp, do: System.monotonic_time(:millisecond)

  defp forward(msg, to, state) do
    state.routes
    |> Map.fetch!(to)
    |> GenServer.cast({msg, System.monotonic_time()})
  end

  defp add_jsonrpc_request(state) do
    jsonrpc_requests =
      state.jsonrpc_requests
      |> Map.put(state.jsonrpc_id, System.monotonic_time())

    state
    |> Map.put(:jsonrpc_id, state.jsonrpc_id + 1)
    |> Map.put(:jsonrpc_requests, jsonrpc_requests)
  end

  defp delete_jsonrpc_request(state, id) do
    jsonrpc_requests = Map.delete(state.jsonrpc_requests, id)
    Map.put(state, :jsonrpc_requests, jsonrpc_requests)
  end

  defp account_channels(accounts) do
    accounts
    |> Enum.map(&{&1.asset |> portfolio_channel(), &1})
    |> Map.new()
  end

  defp portfolio_channel(asset) do
    a = asset |> Atom.to_string() |> String.downcase()
    "user.portfolio.#{a}"
  end
end
