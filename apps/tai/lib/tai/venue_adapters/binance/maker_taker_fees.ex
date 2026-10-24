defmodule Tai.VenueAdapters.Binance.MakerTakerFees do
  alias Tai.VenueAdapters.Binance.Error

  def maker_taker_fees(_venue_id, _credential_id, credentials) do
    venue_credentials = struct!(ExBinance.Credentials, credentials)

    with {:ok, account} <- ExBinance.Spot.Private.account(venue_credentials) do
      percent_factor = Decimal.new(10_000)
      maker = account.maker_commission |> Decimal.new() |> Decimal.div(percent_factor)
      taker = account.taker_commission |> Decimal.new() |> Decimal.div(percent_factor)
      {:ok, {maker, taker}}
    else
      {:error, _} = error -> Error.normalize(error)
    end
  end
end
