defmodule Tai.Venues.Product do
  @type status ::
          :pre_trading
          | :trading
          | :post_trading
          | :end_of_day
          | :halt
          | :auction_match
          | :break
          | :settled
          | :unlisted

  @type symbol :: atom
  @type venue_symbol :: String.t()
  @type type :: :spot | :future | :swap | :option
  @type t :: %Tai.Venues.Product{
          venue_id: Tai.Venues.Adapter.venue_id(),
          symbol: symbol,
          venue_symbol: venue_symbol,
          alias: String.t() | nil,
          base: String.t(),
          quote: String.t(),
          status: status,
          type: type,
          price_increment: Decimal.t(),
          size_increment: Decimal.t(),
          min_price: Decimal.t(),
          min_size: Decimal.t(),
          min_notional: Decimal.t() | nil,
          max_price: Decimal.t() | nil,
          max_size: Decimal.t() | nil,
          value: Decimal.t(),
          is_quanto: boolean,
          is_inverse: boolean,
          maker_fee: Decimal.t() | nil,
          taker_fee: Decimal.t() | nil
        }

  @enforce_keys ~w(
    venue_id
    symbol
    venue_symbol
    base
    quote
    status
    type
    price_increment
    size_increment
    min_price
    min_size
  )a
  defstruct ~w(
    venue_id
    symbol
    venue_symbol
    alias
    base
    quote
    status
    type
    price_increment
    size_increment
    min_notional
    min_price
    min_size
    max_size
    max_price
    value
    is_quanto
    is_inverse
    maker_fee
    taker_fee
  )a
end
