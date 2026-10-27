defmodule ExGdax.Market do
  @moduledoc """
  Unauthenticated endpoints for retrieving market data.
  """
  import ExGdax.Api, only: [public_get: 1, public_get: 2]

  def list_currencies do
    public_get("/currencies")
  end

  def get_time do
    public_get("/time")
  end

  def list_products do
    public_get("/products")
  end

  def get_order_book(product_id, params \\ %{}) do
    public_get("/products/#{product_id}/book", params)
  end

  def get_ticker(product_id) do
    public_get("/products/#{product_id}/ticker")
  end

  def list_trades(product_id, params \\ %{}) do
    public_get("/products/#{product_id}/trades", params)
  end

  def list_historic_rates(product_id, params \\ %{}) do
    public_get("/products/#{product_id}/candles", params)
  end

  def get_stats(product_id) do
    public_get("/products/#{product_id}/stats")
  end
end
