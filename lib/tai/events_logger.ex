defmodule Tai.EventsLogger do
  use GenServer
  require Logger

  def start_link(_) do
    GenServer.start_link(__MODULE__, :ok, name: __MODULE__)
  end

  def init(state) do
    Tai.Events.firehose_subscribe()
    {:ok, state}
  end

  # TODO: can't automatically serialize price point tuple to json
  def handle_info({Tai.Event, %Tai.Events.OrderBookSnapshot{} = event}, state) do
    %{
      type: "Tai.OrderBookSnapshot",
      data: %{
        venue_id: event.venue_id,
        symbol: event.symbol
      }
    }
    |> Poison.encode!()
    |> Logger.info(tid: __MODULE__)

    {:noreply, state}
  end

  def handle_info({Tai.Event, event}, state) do
    event
    |> Poison.encode!()
    |> Logger.info(tid: __MODULE__)

    {:noreply, state}
  end
end
