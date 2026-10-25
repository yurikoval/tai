defmodule ExDeribit.Position do
  alias __MODULE__

  @type t :: %Position{
          average_price: number(),
          delta: number,
          direction: String.t(),
          estimated_liquidation_price: number,
          floating_profit_loss: number,
          index_price: number,
          initial_margin: number,
          instrument_name: String.t(),
          leverage: number,
          kind: String.t(),
          maintenance_margin: number,
          mark_price: number,
          open_orders_margin: number,
          realized_profit_loss: number,
          settlement_price: number,
          size_currency: number,
          size: number,
          total_profit_loss: number
        }

  @enforce_keys ~w(
    average_price
    delta
    direction
    estimated_liquidation_price
    floating_profit_loss
    index_price
    initial_margin
    instrument_name
    leverage
    kind
    maintenance_margin
    mark_price
    open_orders_margin
    realized_profit_loss
    settlement_price
    size_currency
    size
    total_profit_loss
  )a
  defstruct ~w(
    average_price
    delta
    direction
    estimated_liquidation_price
    floating_profit_loss
    index_price
    initial_margin
    instrument_name
    leverage
    kind
    maintenance_margin
    mark_price
    open_orders_margin
    realized_profit_loss
    settlement_price
    size_currency
    size
    total_profit_loss
  )a
end
