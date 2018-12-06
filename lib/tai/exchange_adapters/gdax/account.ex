defmodule Tai.ExchangeAdapters.Gdax.Account do
  @moduledoc """
  Execute private exchange actions for the GDAX account
  """
  use Tai.Exchanges.Account

  def all_balances(credentials) do
    Tai.ExchangeAdapters.Gdax.Account.AllBalances.fetch(credentials)
  end

  def create_order(%Tai.Trading.Order{} = order, credentials) do
    Tai.ExchangeAdapters.Gdax.Account.Orders.create(order, credentials)
  end

  def cancel_order(venue_order_id, credentials) do
    Tai.ExchangeAdapters.Gdax.Account.CancelOrder.execute(venue_order_id, credentials)
  end

  def order_status(venue_order_id, credentials) do
    Tai.ExchangeAdapters.Gdax.Account.OrderStatus.fetch(venue_order_id, credentials)
  end
end
