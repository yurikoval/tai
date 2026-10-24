defmodule Tai.VenueAdapters.Binance.Market do
  @type t :: :spot | :usd_margin_futures | :coin_margin_futures

  def from_product(%Tai.Venues.Product{type: :spot}), do: :spot
  def from_product(%Tai.Venues.Product{is_inverse: true}), do: :coin_margin_futures
  def from_product(%Tai.Venues.Product{}), do: :usd_margin_futures

  def rest_client(:spot), do: ExBinance.Rest.SpotClient
  def rest_client(:usd_margin_futures), do: ExBinance.Rest.UsdMarginFuturesClient
  def rest_client(:coin_margin_futures), do: ExBinance.Rest.CoinMarginFuturesClient

  def exchange_info_path(:spot), do: "/api/v3/exchangeInfo"
  def exchange_info_path(:usd_margin_futures), do: "/fapi/v1/exchangeInfo"
  def exchange_info_path(:coin_margin_futures), do: "/dapi/v1/exchangeInfo"

  def depth_path(:spot), do: "/api/v3/depth"
  def depth_path(:usd_margin_futures), do: "/fapi/v1/depth"
  def depth_path(:coin_margin_futures), do: "/dapi/v1/depth"

  def account_path(:spot), do: "/api/v3/account"
  def account_path(:usd_margin_futures), do: "/fapi/v3/account"
  def account_path(:coin_margin_futures), do: "/dapi/v1/account"

  def order_path(:spot), do: "/api/v3/order"
  def order_path(:usd_margin_futures), do: "/fapi/v1/order"
  def order_path(:coin_margin_futures), do: "/dapi/v1/order"

  def websocket_endpoint(:spot), do: "wss://stream.binance.com:9443/ws"
  def websocket_endpoint(:usd_margin_futures), do: "wss://fstream.binance.com/ws"
  def websocket_endpoint(:coin_margin_futures), do: "wss://dstream.binance.com/ws"
end
