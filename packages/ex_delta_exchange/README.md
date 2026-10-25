# ExDeltaExchange
[![Build Status](https://github.com/fremantle-industries/ex_delta_exchange/workflows/test/badge.svg?branch=main)](https://github.com/fremantle-industries/ex_delta_exchange/actions?query=workflow%3Atest)
[![hex.pm version](https://img.shields.io/hexpm/v/ex_delta_exchange.svg?style=flat)](https://hex.pm/packages/ex_delta_exchange)


Delta Exchange API Client for Elixir

## Installation

Add the `ex_ftx` package to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:ex_delta_exchange, "~> 0.0.3"}
  ]
end
```

## Requirements

- Erlang 22+
- Elixir 1.10+

## API Documentation

https://docs.delta.exchange/#introduction

## REST API

#### Assets

- [x] `GET /assets`

#### Indicies

- [x] `GET /indices`

#### Products

- [x] `GET /products`
- [ ] `GET /products/{symbol}`
- [ ] `GET /tickers`
- [ ] `GET /tickers/{symbol}`

#### Orders

- [ ] `POST /orders`
- [ ] `DELETE /orders`
- [ ] `PUT /orders`
- [ ] `GET /orders`
- [ ] `DELETE /orders/all`

#### Positions

- [ ] `GET /positions`
- [ ] `GET /positions/margined`
- [ ] `POST /positions/change_margin`

#### TradeHistory

- [ ] `GET /orders/history`
- [ ] `GET /fills`
- [ ] `GET /fills/history/download/csv`

#### Orderbook

- [ ] `GET /l2orderbook/{symbol}`

#### Trades

- [ ] `GET /trades/{symbol}`

#### Wallet

- [ ] `GET /wallet/balances`
- [ ] `GET /wallet/transactions`
- [ ] `GET /wallet/transactions/download`

#### OHLC Candles

- [ ] `GET /history/candles`
- [ ] `GET /history/sparklines`
