defmodule ExHuobi.Futures.Contract do
  alias __MODULE__

  @type delisting :: 0
  @type listing :: 1
  @type pending_listing :: 2
  @type suspension :: 3
  @type suspending_of_listing :: 4
  @type in_settlement :: 5
  @type delivering :: 6
  @type settlement_completed :: 7
  @type delivered :: 8
  @type suspended_listing :: 9
  @type contract_status ::
          delisting
          | listing
          | pending_listing
          | suspension
          | suspending_of_listing
          | in_settlement
          | delivering
          | settlement_completed
          | delivered
          | suspended_listing

  @type t :: %Contract{
          symbol: String.t(),
          contract_code: String.t(),
          contract_type: String.t(),
          contract_size: non_neg_integer,
          price_tick: number,
          delivery_date: String.t(),
          create_date: String.t(),
          contract_status: contract_status
        }

  defstruct ~w(
    symbol
    contract_code
    contract_type
    contract_size
    price_tick
    delivery_date
    create_date
    contract_status
  )a
end
