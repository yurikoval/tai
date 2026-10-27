defmodule Tai.VenueAdapters.OkEx.Products do
  alias ExOkex.Public

  def products(venue_id) do
    with {:ok, future_instruments} <- Public.instruments("FUTURES"),
         {:ok, swap_instruments} <- Public.instruments("SWAP"),
         {:ok, spot_instruments} <- Public.instruments("SPOT") do
      future_products =
        future_instruments |> Enum.map(&Tai.VenueAdapters.OkEx.Product.build(&1, venue_id))

      swap_products =
        swap_instruments |> Enum.map(&Tai.VenueAdapters.OkEx.Product.build(&1, venue_id))

      spot_products =
        spot_instruments |> Enum.map(&Tai.VenueAdapters.OkEx.Product.build(&1, venue_id))

      products = future_products ++ swap_products ++ spot_products

      {:ok, products}
    end
  end

  defdelegate to_symbol(instrument_id), to: Tai.VenueAdapters.OkEx.Product
end
