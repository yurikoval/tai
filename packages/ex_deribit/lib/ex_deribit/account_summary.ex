defmodule ExDeribit.AccountSummary do
  alias __MODULE__

  @type t :: %AccountSummary{
          available_funds: number,
          available_withdrawal_funds: number,
          balance: number,
          currency: String.t(),
          delta_total: number,
          deposit_address: String.t(),
          email: String.t(),
          equity: number,
          futures_pl: number,
          futures_session_rpl: number,
          futures_session_upl: number,
          id: non_neg_integer,
          initial_margin: number,
          limits: map,
          maintenance_margin: number,
          margin_balance: number,
          options_delta: number,
          options_gamma: number,
          options_pl: number,
          options_session_rpl: number,
          options_session_upl: number,
          options_theta: number,
          options_vega: number,
          portfolio_margining_enabled: boolean,
          session_funding: number,
          session_rpl: number,
          session_upl: number,
          system_name: String.t(),
          tfa_enabled: boolean,
          total_pl: number,
          type: String.t(),
          username: String.t()
        }

  @enforce_keys ~w(
    available_funds
    available_withdrawal_funds
    balance
    currency
    delta_total
    deposit_address
    email
    equity
    futures_pl
    futures_session_rpl
    futures_session_upl
    id
    initial_margin
    limits
    maintenance_margin
    margin_balance
    options_delta
    options_gamma
    options_pl
    options_session_rpl
    options_session_upl
    options_theta
    options_vega
    portfolio_margining_enabled
    session_funding
    session_rpl
    session_upl
    system_name
    tfa_enabled
    total_pl
    type
    username
  )a
  defstruct ~w(
    available_funds
    available_withdrawal_funds
    balance
    currency
    delta_total
    deposit_address
    email
    equity
    futures_pl
    futures_session_rpl
    futures_session_upl
    id
    initial_margin
    limits
    maintenance_margin
    margin_balance
    options_delta
    options_gamma
    options_pl
    options_session_rpl
    options_session_upl
    options_theta
    options_vega
    portfolio_margining_enabled
    session_funding
    session_rpl
    session_upl
    system_name
    tfa_enabled
    total_pl
    type
    username
  )a
end
