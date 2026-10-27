defmodule Tai.VenueAdapters.Deribit.Products do
  require Logger

  alias Tai.VenueAdapters.Deribit.Product

  @instrument_options %{expired: false}

  def products(venue_id) do
    with {:ok, instruments} <- ExDeribit.MarketData.Instruments.get("any", @instrument_options) do
      products = build_products(instruments, venue_id)

      case products do
        [] -> {:error, :no_supported_instruments}
        products -> {:ok, products}
      end
    end
  end

  defp build_products(instruments, venue_id) do
    instruments
    |> Enum.reduce([], fn instrument, products ->
      case Product.build(instrument, venue_id) do
        {:ok, product} ->
          [product | products]

        {:error, reason} ->
          Logger.warning(
            "Deribit ignored instrument #{inspect(instrument.instrument_name)}: #{inspect(reason)}"
          )

          products
      end
    end)
    |> Enum.reverse()
  end
end
