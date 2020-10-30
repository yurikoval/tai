defmodule Tai.VenueAdapters.Bitmex.Product do
  @format "{ISO:Extended}"

  def build(%ExBitmex.Instrument{lot_size: nil}, _), do: nil

  def build(instrument, venue_id) do
    symbol = instrument.symbol |> downcase_and_atom
    type = instrument.expiry |> type()
    status = Tai.VenueAdapters.Bitmex.ProductStatus.normalize(instrument.state)
    listing = instrument.listing && Timex.parse!(instrument.listing, @format)
    expiry = instrument.expiry && Timex.parse!(instrument.expiry, @format)
    {:ok, lot_size} = instrument.lot_size |> Decimal.cast()
    {:ok, tick_size} = instrument.tick_size |> Decimal.cast()

    max_order_qty =
      instrument.max_order_qty && instrument.max_order_qty |> Decimal.cast() |> elem(1)

    max_price = instrument.max_price && instrument.max_price |> Decimal.cast() |> elem(1)
    maker_fee = instrument.maker_fee && instrument.maker_fee |> Decimal.cast() |> elem(1)
    taker_fee = instrument.taker_fee && instrument.taker_fee |> Decimal.cast() |> elem(1)

    %Tai.Venues.Product{
      venue_id: venue_id,
      symbol: symbol,
      venue_symbol: instrument.symbol,
      base: instrument.underlying |> downcase_and_atom(),
      quote: instrument.quote_currency |> downcase_and_atom(),
      venue_base: instrument.underlying,
      venue_quote: instrument.quote_currency,
      status: status,
      type: type,
      listing: listing,
      expiry: expiry,
      price_increment: tick_size,
      size_increment: lot_size,
      min_price: tick_size,
      min_size: Decimal.new(1),
      max_price: max_price,
      max_size: max_order_qty,
      value: lot_size,
      is_quanto: instrument.is_quanto,
      is_inverse: instrument.is_inverse,
      maker_fee: maker_fee,
      taker_fee: taker_fee
    }
  end

  def downcase_and_atom(str), do: str |> String.downcase() |> String.to_atom()

  def from_symbol(symbol) do
    symbol
    |> Atom.to_string()
    |> String.upcase()
  end

  defp type(nil), do: :swap
  defp type(_), do: :future
end
