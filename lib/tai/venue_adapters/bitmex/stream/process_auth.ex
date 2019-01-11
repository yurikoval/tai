defmodule Tai.VenueAdapters.Bitmex.Stream.ProcessAuthMessages do
  use GenServer
  alias Tai.VenueAdapters.Bitmex.Stream
  require Logger

  @type t :: %Stream.ProcessAuthMessages{
          venue_id: atom
        }

  @enforce_keys [:venue_id]
  defstruct [:venue_id]

  def start_link(venue_id: venue_id) do
    state = %Stream.ProcessAuthMessages{venue_id: venue_id}
    GenServer.start_link(__MODULE__, state, name: venue_id |> to_name())
  end

  def init(state), do: {:ok, state}

  @spec to_name(venue_id :: atom) :: atom
  def to_name(venue_id), do: :"#{__MODULE__}_#{venue_id}"

  def handle_cast({%{"table" => "wallet", "action" => "partial"}, _received_at}, state) do
    {:noreply, state}
  end

  def handle_cast({%{"table" => "margin", "action" => "partial"}, _received_at}, state) do
    {:noreply, state}
  end

  def handle_cast(
        {%{"table" => "margin", "action" => "update", "data" => _data}, _received_at},
        state
      ) do
    {:noreply, state}
  end

  # [
  #   %{
  #     "avgCostPrice" => nil, 
  #     "grossOpenCost" => 0, 
  #     "posCross" => 0, 
  #     "unrealisedCost" => 0, 
  #     "marginCallPrice" => nil, 
  #     "currentTimestamp" => "2019-01-11T01:00:00.399Z", 
  #     "markValue" => 0, 
  #     "simpleCost" => nil, 
  #     "openingComm" => 0, 
  #     "execQty" => 0, 
  #     "unrealisedPnlPcnt" => 0, 
  #     "realisedPnl" => 0, 
  #     "liquidationPrice" => nil, 
  #     "deleveragePercentile" => nil, 
  #     "rebalancedPnl" => 0, 
  #     "varMargin" => 0, 
  #     "openingTimestamp" => "2019-01-11T01:00:00.000Z", 
  #     "execSellQty" => 0, 
  #     "openOrderSellCost" => 0, 
  #     "initMarginReq" => 0.01, 
  #     "realisedCost" => 0, 
  #     "isOpen" => false, 
  #     "posAllowance" => 0, 
  #     "unrealisedGrossPnl" => 0, 
  #     "breakEvenPrice" => nil, 
  #     "currency" => "XBt", 
  #     "quoteCurrency" => "USD", 
  #     "longBankrupt" => 0, 
  #     "homeNotional" => 0, 
  #     "openOrderSellPremium" => 0, 
  #     "realisedGrossPnl" => 0, 
  #     "lastValue" => 0, 
  #     "currentComm" => 0, 
  #     "openOrderBuyPremium" => 0, 
  #     "underlying" => "XBT", 
  #     "simpleValue" => nil, 
  #     "markPrice" => nil, 
  #     "timestamp" => "2019-01-11T01:00:00.399Z", 
  #     "taxableMargin" => 0, 
  #     "taxBase" => 0, 
  #     "crossMargin" => true, 
  #     "execCost" => 0, 
  #     "openingCost" => 0, 
  #     "simplePnl" => nil, 
  #     "avgEntryPrice" => nil, 
  #     "initMargin" => 0, 
  #     "posState" => "", 
  #     "posMargin" => 0, 
  #     "prevRealisedPnl" => -1751,
  #     ...
  #   }, 
  #   %{"avgCostPrice" => nil, "grossOpenCost" => 0, "posCross" => 0, "unrealisedCost" => 0, "marginCallPrice" => nil, "currentTimestamp" => "2019-01-11T01:00:00.399Z", "markValue" => 0, "simpleCost" => nil, "openingComm" => 0, "execQty" => 0, "unrealisedPnlPcnt" => 0, "realisedPnl" => 0, "liquidationPrice" => nil, "deleveragePercentile" => nil, "rebalancedPnl" => 0, "varMargin" => 0, "openingTimestamp" => "2019-01-11T01:00:00.000Z", "execSellQty" => 0, "openOrderSellCost" => 0, "initMarginReq" => 0.01, "realisedCost" => 0, "isOpen" => false, "posAllowance" => 0, "unrealisedGrossPnl" => 0, "breakEvenPrice" => nil, "currency" => "XBt", "quoteCurrency" => "USD", "longBankrupt" => 0, "homeNotional" => 0, "openOrderSellPremium" => 0, "realisedGrossPnl" => 0, "lastValue" => 0, "currentComm" => 0, "openOrderBuyPremium" => 0, "underlying" => "XBT", "simpleValue" => nil, "markPrice" => nil, "timestamp" => "2019-01-11T01:00:00.399Z", "taxableMargin" => 0, "taxBase" => 0, "crossMargin" => true, "execCost" => 0, "openingCost" => 0, "simplePnl" => nil, "avgEntryPrice" => nil, "initMargin" => 0, "posState" => "", "posMargin" => 0, ...}
  # ]
  def handle_cast(
        {%{"table" => "position", "action" => "partial", "data" => _positions}, _received_at},
        state
      ) do
    # positions
    # |> Enum.each(fn position ->
    #   IO.puts("--- POSITION partial position: #{inspect(position)}")
    # end)

    {:noreply, state}
  end

  def handle_cast(
        {%{"table" => "position", "action" => "insert", "data" => _positions}, _received_at},
        state
      ) do
    # IO.puts("--- POSITION insert - #{inspect(positions)}")
    {:noreply, state}
  end

  def handle_cast(
        {%{"table" => "position", "action" => "update", "data" => _positions}, _received_at},
        state
      ) do
    # positions
    # |> Enum.each(fn %{"symbol" => exchange_symbol} = p ->
    #   Tai.Events.broadcast(%Tai.Events.PositionUpdate{
    #     venue_id: state.venue_id,
    #     symbol: exchange_symbol |> String.downcase() |> String.to_atom(),
    #     received_at: received_at,
    #     data: p
    #   })
    # end)

    {:noreply, state}
  end

  # [
  #   %{
  #     "side" => "Buy",
  #     "transactTime" => "2019-01-14T03:20:55.829Z",
  #     "ordType" => "Limit",
  #     "displayQty" => nil,
  #     "stopPx" => nil,
  #     "settlCurrency" => "XBt",
  #     "triggered" => "",
  #     "orderID" => "13852f63-ee0d-b291-ed92-f519e3bbadc7",
  #     "currency" => "USD",
  #     "pegOffsetValue" => nil,
  #     "price" => 3459.5,
  #     "pegPriceType" => "",
  #     "text" => "Submitted via API.",
  #     "workingIndicator" => true,
  #     "multiLegReportingType" => "SingleSecurity",
  #     "timestamp" => "2019-01-14T03:20:55.829Z",
  #     "cumQty" => 0,
  #     "ordRejReason" => "",
  #     "avgPx" => nil,
  #     "orderQty" => 10,
  #     "simpleOrderQty" => nil,
  #     "ordStatus" => "New",
  #     "timeInForce" => "GoodTillCancel",
  #     "clOrdLinkID" => "",
  #     "simpleLeavesQty" => nil,
  #     "leavesQty" => 10,
  #     "exDestination" => "XBME",
  #     "symbol" => "XBTM19",
  #     "account" => 158_677,
  #     "clOrdID" => "",
  #     "simpleCumQty" => nil,
  #     "execInst" => "ParticipateDoNotInitiate",
  #     "contingencyType" => ""
  #   },
  #   %{
  #     "side" => "Sell",
  #     "transactTime" => "2019-01-14T03:24:08.305Z",
  #     "ordType" => "Limit",
  #     "displayQty" => nil,
  #     "stopPx" => nil,
  #     "settlCurrency" => "XBt",
  #     "triggered" => "",
  #     "orderID" => "29d7584f-0ba9-c281-8810-5485ee88a638",
  #     "currency" => "USD",
  #     "pegOffsetValue" => nil,
  #     "price" => 3881.5,
  #     "pegPriceType" => "",
  #     "text" => "Amended leavesQty price: Amended via API.\nSubmitted via API.",
  #     "workingIndicator" => true,
  #     "multiLegReportingType" => "SingleSecurity",
  #     "timestamp" => "2019-01-14T03:24:08.305Z",
  #     "cumQty" => 0,
  #     "ordRejReason" => "",
  #     "avgPx" => nil,
  #     "orderQty" => 10,
  #     "simpleOrderQty" => nil,
  #     "ordStatus" => "New",
  #     "timeInForce" => "GoodTillCancel",
  #     "clOrdLinkID" => "",
  #     "simpleLeavesQty" => nil,
  #     "leavesQty" => 10,
  #     "exDestination" => "XBME",
  #     "symbol" => "XBTH19",
  #     "account" => 158_677,
  #     "clOrdID" => "",
  #     "simpleCumQty" => nil,
  #     "execInst" => "ParticipateDoNotInitiate",
  #     "contingencyType" => ""
  #   }
  # ]
  def handle_cast(
        {%{"table" => "order", "action" => "partial", "data" => _data}, _received_at},
        state
      ) do
    # IO.puts("--- ORDER partial - #{inspect(data)}")
    {:noreply, state}
  end

  # [
  #   %{
  #     "side" => "Buy",
  #     "transactTime" => "2019-01-11T01:44:05.570Z",
  #     "ordType" => "Limit",
  #     "displayQty" => nil,
  #     "stopPx" => nil,
  #     "settlCurrency" => "XBt",
  #     "triggered" => "",
  #     "orderID" => "54bc4632-5bfd-c111-2942-85f466289024",
  #     "currency" => "USD",
  #     "pegOffsetValue" => nil,
  #     "price" => 3710.5,
  #     "pegPriceType" => "",
  #     "text" => "Submission from testnet.bitmex.com",
  #     "workingIndicator" => false,
  #     "multiLegReportingType" => "SingleSecurity",
  #     "timestamp" => "2019-01-11T01:44:05.570Z",
  #     "cumQty" => 0,
  #     "ordRejReason" => "",
  #     "avgPx" => nil,
  #     "orderQty" => 2,
  #     "simpleOrderQty" => nil,
  #     "ordStatus" => "New",
  #     "timeInForce" => "GoodTillCancel",
  #     "clOrdLinkID" => "",
  #     "simpleLeavesQty" => nil,
  #     "leavesQty" => 2,
  #     "exDestination" => "XBME",
  #     "symbol" => "XBTH19",
  #     "account" => 158_677,
  #     "clOrdID" => "",
  #     "simpleCumQty" => nil,
  #     "execInst" => "",
  #     "contingencyType" => ""
  #   }
  # ]
  def handle_cast(
        {%{"table" => "order", "action" => "insert", "data" => _data}, _received_at},
        state
      ) do
    # IO.puts("--- ORDER insert - #{inspect(data)}")
    {:noreply, state}
  end

  # %{
  #     "table":"order",
  #     "data":[
  #       {
  #         "workingIndicator":false,
  #         "timestamp":"2018-12-27T05:33:50.795Z",
  #         "symbol":"XBTH19",
  #         "orderID":"7f3bae18-b96d-6d4d-27f0-a11f52d4b6b4",
  #         "ordStatus":"Filled",
  #         "leavesQty":0,
  #         "cumQty":2,
  #         "clOrdID":"",
  #         "avgPx":4265,
  #         "account":158677
  #       }
  #     ],
  #     "action":"update"
  #   }
  def handle_cast(
        {%{"table" => "order", "action" => "update", "data" => orders}, _received_at},
        state
      ) do
    orders
    |> Enum.each(fn
      %{"orderID" => venue_order_id, "ordStatus" => venue_status} = venue_order ->
        IO.puts("--- ORDER update venue_order: - #{inspect(venue_order)}")

        Task.async(fn ->
          status =
            venue_status
            |> Tai.VenueAdapters.Bitmex.OrderStatus.from_venue_status(:ignore)

          leaves_qty =
            venue_order
            |> Map.fetch!("leavesQty")
            |> Decimal.new()

          attrs = [status: status, leaves_qty: leaves_qty]

          attrs =
            unless status == :canceled do
              cumulative_qty =
                venue_order
                |> Map.fetch!("cumQty")
                |> Decimal.new()

              avg_price =
                venue_order
                |> Map.fetch!("avgPx")
                |> Tai.Utils.Decimal.from()

              attrs
              |> Keyword.put(:cumulative_qty, cumulative_qty)
              |> Keyword.put(:avg_price, avg_price)
            else
              attrs
            end

          with {:ok, {prev_order, updated_order}} <-
                 Tai.Trading.OrderStore.find_by_and_update(
                   [venue_order_id: venue_order_id],
                   attrs
                 ) do
            Tai.Trading.Orders.updated!(prev_order, updated_order)
          else
            {:error, :not_found} ->
              Tai.Events.broadcast(%Tai.Events.OrderNotFound{
                venue_order_id: venue_order_id
              })
          end
        end)

      %{"orderID" => venue_order_id} = venue_order ->
        IO.puts(
          "--- ORDER update venue_order no status so just ignore... #{venue_order_id} | venue_order: #{
            inspect(venue_order)
          }"
        )
    end)

    {:noreply, state}
  end

  def handle_cast(
        {%{"table" => "execution", "action" => "partial", "data" => _data}, _received_at},
        state
      ) do
    # IO.puts("--- EXECUTION partial - #{inspect(data)}")
    {:noreply, state}
  end

  # [
  #   %{
  #     "side" => "Buy",
  #     "transactTime" => "2019-01-11T01:44:05.570Z",
  #     "ordType" => "Limit",
  #     "lastLiquidityInd" => "",
  #     "displayQty" => nil,
  #     "stopPx" => nil,
  #     "settlCurrency" => "XBt",
  #     "trdMatchID" => "00000000-0000-0000-0000-000000000000",
  #     "lastMkt" => "",
  #     "triggered" => "",
  #     "orderID" => "54bc4632-5bfd-c111-2942-85f466289024",
  #     "currency" => "USD",
  #     "pegOffsetValue" => nil,
  #     "price" => 3710.5,
  #     "homeNotional" => nil,
  #     "pegPriceType" => "",
  #     "text" => "Submission from testnet.bitmex.com",
  #     "workingIndicator" => true,
  #     "multiLegReportingType" => "SingleSecurity",
  #     "timestamp" => "2019-01-11T01:44:05.570Z",
  #     "cumQty" => 0,
  #     "ordRejReason" => "",
  #     "execCost" => nil,
  #     "avgPx" => nil,
  #     "lastQty" => nil,
  #     "lastPx" => nil,
  #     "orderQty" => 2,
  #     "simpleOrderQty" => nil,
  #     "ordStatus" => "New",
  #     "timeInForce" => "GoodTillCancel",
  #     "clOrdLinkID" => "",
  #     "execComm" => nil,
  #     "simpleLeavesQty" => nil,
  #     "tradePublishIndicator" => "",
  #     "leavesQty" => 2,
  #     "commission" => nil,
  #     "execID" => "ff26891e-c000-3faa-b6c6-105514dd9943",
  #     "exDestination" => "XBME",
  #     "symbol" => "XBTH19",
  #     "account" => 158_677,
  #     "clOrdID" => "",
  #     "execType" => "New",
  #     "foreignNotional" => nil,
  #     "simpleCumQty" => nil,
  #     "execInst" => "",
  #     "contingencyType" => "",
  #     "underlyingLastPx" => nil
  #   }
  # ]
  def handle_cast(
        {%{"table" => "execution", "action" => "insert", "data" => _data}, _received_at},
        state
      ) do
    # IO.puts("--- EXECUTION insert - #{inspect(data)}")
    {:noreply, state}
  end

  def handle_cast({%{"table" => "transact", "action" => "partial"}, _received_at}, state) do
    {:noreply, state}
  end

  def handle_cast({msg, _received_at}, state) do
    Tai.Events.broadcast(%Tai.Events.StreamMessageUnhandled{
      venue_id: state.venue_id,
      msg: msg
    })

    {:noreply, state}
  end

  # TODO: Handle this message
  # - Pretty sure this is coming from async order update task when it exits ^
  def handle_info(_msg, state) do
    # IO.puts("!!!!!!!!! IN handle_info - msg: #{inspect(msg)}")
    {:noreply, state}
  end
end
