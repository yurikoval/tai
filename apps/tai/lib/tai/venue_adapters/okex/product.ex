defmodule Tai.VenueAdapters.OkEx.Product do
  alias ExOkex.Public.Instrument
  alias Tai.Utils.Decimal

  @spec build(Instrument.t(), Tai.Venue.id()) :: Tai.Venues.Product.t()
  def build(%Instrument{} = instrument, venue_id) do
    case instrument.instrument_type do
      "FUTURES" -> build_future(instrument, venue_id)
      "SWAP" -> build_swap(instrument, venue_id)
      "SPOT" -> build_spot(instrument, venue_id)
      type -> raise ArgumentError, "unsupported OKX instrument type #{inspect(type)}"
    end
  end

  defp build_future(instrument, venue_id) do
    {base, quote} = base_and_quote(instrument)

    build_product(
      type: :future,
      venue_id: venue_id,
      venue_symbol: instrument.instrument_id,
      alias: blank_to_nil(instrument.alias),
      base: base,
      quote: quote,
      status: status(instrument.state),
      listing: timestamp(instrument.listing_time),
      expiry: timestamp(instrument.expiry_time),
      venue_price_increment: instrument.tick_size,
      venue_size_increment: instrument.lot_size,
      venue_min_size: instrument.minimum_size,
      value: instrument.contract_value,
      value_side: value_side(instrument.contract_value_currency, base, quote),
      is_inverse: instrument.contract_type == "inverse",
      is_quanto: false
    )
  end

  defp build_swap(instrument, venue_id) do
    {base, quote} = base_and_quote(instrument)

    build_product(
      type: :swap,
      venue_id: venue_id,
      venue_symbol: instrument.instrument_id,
      base: base,
      quote: quote,
      status: status(instrument.state),
      listing: timestamp(instrument.listing_time),
      expiry: timestamp(instrument.expiry_time),
      venue_price_increment: instrument.tick_size,
      venue_size_increment: instrument.lot_size,
      venue_min_size: instrument.minimum_size,
      value: instrument.contract_value,
      value_side: value_side(instrument.contract_value_currency, base, quote),
      is_inverse: instrument.contract_type == "inverse",
      is_quanto: false
    )
  end

  defp build_spot(instrument, venue_id) do
    build_product(
      type: :spot,
      venue_id: venue_id,
      venue_symbol: instrument.instrument_id,
      base: instrument.base_currency,
      quote: instrument.quote_currency,
      status: status(instrument.state),
      listing: timestamp(instrument.listing_time),
      venue_price_increment: instrument.tick_size,
      venue_size_increment: instrument.lot_size,
      venue_min_size: instrument.minimum_size,
      value: 1,
      value_side: :base,
      is_inverse: false,
      is_quanto: false
    )
  end

  def to_symbol(instrument_id) do
    instrument_id
    |> String.replace("-", "_")
    |> downcase_and_atom
  end

  defp base_and_quote(instrument) do
    underlying = blank_to_nil(instrument.underlying) || blank_to_nil(instrument.instrument_family)

    case underlying && String.split(underlying, "-", parts: 2) do
      [base, quote] -> {base, quote}
      _ -> raise ArgumentError, "invalid OKX underlying for #{instrument.instrument_id}"
    end
  end

  defp value_side(contract_value_currency, base, _quote) when contract_value_currency == base,
    do: :base

  defp value_side(contract_value_currency, _base, quote) when contract_value_currency == quote,
    do: :quote

  defp value_side(contract_value_currency, base, quote) do
    raise ArgumentError,
          "OKX contract value currency #{inspect(contract_value_currency)} is neither #{base} nor #{quote}"
  end

  defp status("live"), do: :trading
  defp status("preopen"), do: :pre_trading
  defp status("post_only"), do: :restricted
  defp status(state) when state in ["suspend", "rebase", "test"], do: :halt
  defp status("settling"), do: :post_trading
  defp status("expired"), do: :settled
  defp status(_), do: :unknown

  defp timestamp(value) when value in [nil, ""], do: nil

  defp timestamp(value) do
    {milliseconds, ""} = Integer.parse(value)
    DateTime.from_unix!(milliseconds, :millisecond)
  end

  defp blank_to_nil(value) when value in [nil, ""], do: nil
  defp blank_to_nil(value), do: value

  defp downcase_and_atom(str), do: str |> String.downcase() |> String.to_atom()

  defp build_product(args) do
    venue_symbol = Keyword.fetch!(args, :venue_symbol)
    product_alias = Keyword.get(args, :alias)
    venue_size_increment = Keyword.fetch!(args, :venue_size_increment)

    symbol = to_symbol(venue_symbol)
    price_increment = args |> Keyword.fetch!(:venue_price_increment) |> Decimal.cast!()
    size_increment = Decimal.cast!(venue_size_increment)

    min_size =
      args |> Keyword.get(:venue_min_size, venue_size_increment) |> Decimal.cast!()

    value = args |> Keyword.fetch!(:value) |> Decimal.cast!()
    value_side = Keyword.fetch!(args, :value_side)
    listing = Keyword.get(args, :listing)
    expiry = Keyword.get(args, :expiry)
    base_asset = Keyword.fetch!(args, :base)
    quote_asset = Keyword.fetch!(args, :quote)

    %Tai.Venues.Product{
      venue_id: Keyword.fetch!(args, :venue_id),
      symbol: symbol,
      venue_symbol: venue_symbol,
      alias: product_alias,
      base: downcase_and_atom(base_asset),
      quote: downcase_and_atom(quote_asset),
      venue_base: base_asset,
      venue_quote: quote_asset,
      status: Keyword.fetch!(args, :status),
      type: Keyword.fetch!(args, :type),
      listing: listing,
      expiry: expiry,
      collateral: false,
      price_increment: price_increment,
      size_increment: size_increment,
      min_price: price_increment,
      min_size: min_size,
      value: value,
      value_side: value_side,
      is_quanto: Keyword.fetch!(args, :is_quanto),
      is_inverse: Keyword.fetch!(args, :is_inverse)
    }
  end
end
