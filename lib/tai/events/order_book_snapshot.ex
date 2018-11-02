defmodule Tai.Events.OrderBookSnapshot do
  @type t :: %Tai.Events.OrderBookSnapshot{
          # state: term,
          venue_id: atom,
          symbol: atom,
          snapshot: term
        }

  @enforce_keys [:venue_id, :symbol, :snapshot]
  defstruct [:venue_id, :symbol, :snapshot]
end

defimpl Poison.Encoder, for: Tai.Events.OrderBookSnapshot do
  def encode(event, options) do
    %{
      type: "Tai.OrderBookSnapshot",
      data: %{
        # state: inspect(event.state)
        venue_id: event.venue_id,
        symbol: event.symbol,
        snapshot: event.snapshot
      }
    }
    |> Poison.encode!()
  end
end
