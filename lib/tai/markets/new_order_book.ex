defmodule Tai.Markets.NewOrderBook do
  @type price_point :: Tai.Markets.PricePoint.t()
  # TODO: Figure out if a tuple or a list is faster once implimented...
  # @type price_ladder :: {}
  @type price_ladder :: [price_point]

  @type t :: %Tai.Markets.NewOrderBook{
          bids: price_ladder,
          asks: price_ladder
        }

  defstruct [:bids, :asks]
end
