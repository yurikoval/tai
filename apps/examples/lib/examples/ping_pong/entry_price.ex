defmodule Examples.PingPong.EntryPrice do
  alias Tai.Markets.Quote

  @type market_quote :: Quote.t()
  @type product :: Tai.Venues.Product.t()

  @spec calculate(market_quote, product) :: Decimal.t()
  def calculate(%Quote{asks: [inside_ask | _]}, product) do
    inside_ask.price |> Decimal.cast() |> elem(1) |> Decimal.sub(product.price_increment)
  end
end
