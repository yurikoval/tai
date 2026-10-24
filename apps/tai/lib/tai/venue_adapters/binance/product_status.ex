defmodule Tai.VenueAdapters.Binance.ProductStatus do
  @type status :: Tai.Venues.Product.status()

  @spec normalize(binance_status :: String.t()) :: {:ok, status} | {:error, :unknown_status}
  def normalize(binance_status)

  def normalize(status) when status in ["PRE_TRADING", "PENDING_TRADING"],
    do: {:ok, Tai.Venues.ProductStatus.pre_trading()}

  def normalize("TRADING"), do: {:ok, Tai.Venues.ProductStatus.trading()}

  def normalize(status) when status in ["POST_TRADING", "PRE_SETTLE", "PRE_DELIVERING"],
    do: {:ok, Tai.Venues.ProductStatus.post_trading()}

  def normalize(status) when status in ["END_OF_DAY", "SETTLING", "DELIVERING"],
    do: {:ok, Tai.Venues.ProductStatus.end_of_day()}

  def normalize("HALT"), do: {:ok, Tai.Venues.ProductStatus.halt()}
  def normalize("AUCTION_MATCH"), do: {:ok, Tai.Venues.ProductStatus.auction_match()}
  def normalize("BREAK"), do: {:ok, Tai.Venues.ProductStatus.break()}

  def normalize(status) when status in ["CLOSE", "DELIVERED"],
    do: {:ok, Tai.Venues.ProductStatus.settled()}

  def normalize(_), do: {:error, :unknown_status}
end
