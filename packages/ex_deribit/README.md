# ExDeribit
[![Build Status](https://github.com/fremantle-capital/ex_deribit/workflows/test/badge.svg?branch=main)](https://github.com/fremantle-capital/ex_deribit/actions?query=workflow%3ATest)
[![Coverage Status](https://coveralls.io/repos/github/fremantle-capital/ex_deribit/badge.svg?branch=main)](https://coveralls.io/github/fremantle-capital/ex_deribit?branch=main)
[![hex.pm version](https://img.shields.io/hexpm/v/ex_deribit.svg?style=flat)](https://hex.pm/packages/ex_deribit)

Deribit API Client for Elixir

## Installation

Add the `ex_deribit` package to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_deribit, "~> 0.0.9"}
  ]
end
```

## REST Status V2.0.0

https://docs.deribit.com/v2/#deribit-api-v2-0-0

#### Account Management

- [x] `/public/get_announcements`
- [ ] `/private/change_api_key_name`
- [ ] `/private/change_scope_in_api_key`
- [ ] `/private/change_subaccount_name`
- [ ] `/private/create_api_key`
- [ ] `/private/create_subaccount`
- [ ] `/private/disable_api_key`
- [ ] `/private/disable_tfa_for_subaccount`
- [ ] `/private/enable_api_key`
- [x] `/private/get_account_summary`
- [ ] `/private/get_email_language`
- [ ] `/private/get_new_announcements`
- [x] `/private/get_position`
- [x] `/private/get_positions`
- [ ] `/private/get_subaccounts`
- [ ] `/private/list_api_keys`
- [ ] `/private/remove_api_key`
- [ ] `/private/reset_api_key`
- [ ] `/private/set_announcement_as_read`
- [ ] `/private/set_api_key_as_default`
- [ ] `/private/set_email_for_subaccount`
- [ ] `/private/set_email_language`
- [ ] `/private/set_password_for_subaccount`
- [ ] `/private/toggle_notifications_from_subaccount`
- [ ] `/private/toggle_subaccount_login`

#### Block Trade

- [ ] `/private/execute_block_trade`
- [ ] `/private/get_block_trade`
- [ ] `/private/get_last_block_trades_by_currency`
- [ ] `/private/invalidate_block_trade_signature`
- [ ] `/private/verify_block_trade`

#### Trade

- [ ] `/private/buy`
- [ ] `/private/sell`
- [ ] `/private/edit`
- [ ] `/private/cancel`
- [ ] `/private/cancel_all`
- [ ] `/private/cancel_all_by_currency`
- [ ] `/private/cancel_all_by_instrument`
- [ ] `/private/cancel_by_label`
- [ ] `/private/close_position`
- [ ] `/private/get_margins`
- [ ] `/private/get_open_orders_by_currency`
- [ ] `/private/get_open_orders_by_instrument`
- [ ] `/private/get_order_history_by_currency`
- [ ] `/private/get_order_history_by_instrument`
- [ ] `/private/get_order_history_by_currency`
- [ ] `/private/get_order_margin_by_ids`
- [ ] `/private/get_order_state`
- [ ] `/private/get_stop_order_history`
- [ ] `/private/get_user_trades_by_currency`
- [ ] `/private/get_user_trades_by_currency_and_time`
- [ ] `/private/get_user_trades_by_instrument`
- [ ] `/private/get_user_trades_by_instrument_and_time`
- [ ] `/private/get_user_trades_by_order`
- [ ] `/private/get_settlement_history_by_instrument`
- [ ] `/private/get_settlement_history_by_currency`

#### Market Data

- [ ] `/public/get_book_summary_by_currency`
- [ ] `/public/get_book_summary_by_instrument`
- [ ] `/public/get_contract_size`
- [x] `/public/get_currencies`
- [ ] `/public/get_funding_chart_data`
- [ ] `/public/get_funding_rate_history`
- [ ] `/public/get_funding_rate_value`
- [ ] `/public/get_historical_volatility`
- [ ] `/public/get_index`
- [x] `/public/get_instruments`
- [ ] `/public/get_last_settlements_by_currency`
- [ ] `/public/get_last_settlements_by_instrument`
- [ ] `/public/get_last_trades_by_currency`
- [ ] `/public/get_last_trades_by_currency_and_time`
- [ ] `/public/get_last_trades_by_instrument`
- [ ] `/public/get_last_trades_by_instrument_and_time`
- [ ] `/public/get_order_book`
- [ ] `/public/get_trade_volumes`
- [ ] `/public/get_tradingview_chart_data`
- [ ] `/public/ticker`

#### Wallet

- [ ] `/private/cancel_transfer_by_id`
- [ ] `/private/cancel_withdrawal`
- [ ] `/private/create_deposit_address`
- [ ] `/private/get_current_deposit_address`
- [ ] `/private/get_deposits`
- [ ] `/private/get_transfers`
- [ ] `/private/get_withdrawals`
- [ ] `/private/submit_transfer_to_subaccount`
- [ ] `/private/submit_transfer_to_user`
- [ ] `/private/withdraw`

## Authors

* Alex Kwiatkowski - alex+git@rival-studios.com

## License

`ex_deribit` is released under the [MIT license](./LICENSE.md)
