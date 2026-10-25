defmodule ExDeribit.Currency do
  alias __MODULE__

  @type withdrawal_priority :: %{
          String.t() => number | String.t()
        }
  @type t :: %Currency{
          coin_type: String.t(),
          currency: String.t(),
          currency_long: String.t(),
          disabled_deposit_address_creation: boolean,
          fee_precision: non_neg_integer,
          min_confirmations: non_neg_integer,
          min_withdrawal_fee: number,
          withdrawal_fee: number,
          withdrawal_priorities: [withdrawal_priority]
        }

  defstruct ~w(
    coin_type
    currency
    currency_long
    disabled_deposit_address_creation
    fee_precision
    min_confirmations
    min_withdrawal_fee
    withdrawal_fee
    withdrawal_priorities
  )a
end
