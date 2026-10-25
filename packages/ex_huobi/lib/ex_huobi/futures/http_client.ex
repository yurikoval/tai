defmodule ExHuobi.Futures.HTTPClient do
  use ExHuobi.Rest.HTTPClient

  def rest_protocol, do: Application.get_env(:ex_huobi, :futures_rest_protocol, "https://")

  def domain, do: Application.get_env(:ex_huobi, :futures_domain, "api.hbdm.com")

  def origin, do: rest_protocol() <> domain()

  def api_path, do: Application.get_env(:ex_huobi, :api_path, "/api/v1")
end
