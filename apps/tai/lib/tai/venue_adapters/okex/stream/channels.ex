defmodule Tai.VenueAdapters.OkEx.Stream.Channels do
  @order "order"
  @depth "books"
  @trade "trades"

  def order(product) do
    prefix = prefix(product)
    "#{prefix}/#{@order}:#{product.venue_symbol}"
  end

  def depth(product), do: %{channel: @depth, instId: product.venue_symbol}
  def trade(product), do: %{channel: @trade, instId: product.venue_symbol}

  defp prefix(%Tai.Venues.Product{type: :future}), do: :futures
  defp prefix(product), do: product.type
end
