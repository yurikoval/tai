defmodule ExDeltaExchange.Asset do
  @type t :: %__MODULE__{
    id: non_neg_integer,
    symbol: String.t(),
    precision: non_neg_integer,
    deposit_status: String.t(),
    withdrawal_status: String.t(),
    base_withdrawal_fee: String.t(),
    min_withdrawal_amount: String.t()
  }

  defstruct ~w[
    id
    symbol
    precision
    deposit_status
    withdrawal_status
    base_withdrawal_fee
    min_withdrawal_amount
  ]a
end
