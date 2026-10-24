defmodule Tai.VenueAdapters.Binance.Products do
  alias Tai.VenueAdapters.Binance.{Error, Market, ProductStatus}

  def products(venue_id, market \\ :spot) do
    client = Market.rest_client(market)
    path = Market.exchange_info_path(market)

    with {:ok, %{"symbols" => venue_products}} <- client.get(path, %{}) do
      {:ok, Enum.map(venue_products, &build(&1, venue_id, market))}
    else
      {:error, _} = error -> Error.normalize(error)
    end
  end

  defp build(venue_product, venue_id, market) do
    base_asset = Map.fetch!(venue_product, "baseAsset")
    quote_asset = Map.fetch!(venue_product, "quoteAsset")
    venue_symbol = Map.fetch!(venue_product, "symbol")
    filters = Map.fetch!(venue_product, "filters")
    {min_price, max_price, tick_size} = price_filter(filters)
    {min_size, max_size, step_size} = size_filter(filters)

    %Tai.Venues.Product{
      venue_id: venue_id,
      symbol: to_symbol(venue_product, market),
      venue_symbol: venue_symbol,
      base: downcase_and_atom(base_asset),
      quote: downcase_and_atom(quote_asset),
      venue_base: base_asset,
      venue_quote: quote_asset,
      status: status(venue_product),
      type: type(venue_product, market),
      listing: timestamp(venue_product["onboardDate"], market),
      expiry: expiry(venue_product, market),
      collateral: false,
      price_increment: tick_size,
      size_increment: step_size,
      min_price: min_price,
      min_size: min_size,
      min_notional: notional_filter(filters),
      max_price: max_price,
      max_size: max_size,
      value: value(venue_product, market),
      value_side: value_side(market),
      is_quanto: false,
      is_inverse: market == :coin_margin_futures
    }
  end

  def to_symbol(%{"baseAsset" => base, "quoteAsset" => quote}, :spot) do
    Tai.Symbol.build(base, quote)
  end

  def to_symbol(%{"symbol" => venue_symbol}, _market), do: downcase_and_atom(venue_symbol)

  def to_symbol(venue_symbol, _market) when is_binary(venue_symbol),
    do: downcase_and_atom(venue_symbol)

  defp status(venue_product) do
    venue_product
    |> Map.get("status", Map.get(venue_product, "contractStatus"))
    |> ProductStatus.normalize()
    |> case do
      {:ok, status} -> status
      {:error, :unknown_status} -> :unknown
    end
  end

  defp type(_venue_product, :spot), do: :spot

  defp type(%{"contractType" => contract_type}, _market)
       when contract_type in ["PERPETUAL", "PERPETUAL_DELIVERING"],
       do: :swap

  defp type(_venue_product, _market), do: :future

  defp expiry(%{"contractType" => contract_type}, _market)
       when contract_type in ["PERPETUAL", "PERPETUAL_DELIVERING"],
       do: nil
  defp expiry(%{"deliveryDate" => value}, market), do: timestamp(value, market)
  defp expiry(_, _market), do: nil

  defp timestamp(_, :spot), do: nil
  defp timestamp(nil, _market), do: nil
  defp timestamp(value, _market), do: DateTime.from_unix!(value, :millisecond)

  defp value(%{"contractSize" => contract_size}, :coin_margin_futures),
    do: to_decimal(contract_size)

  defp value(_, _market), do: Decimal.new(1)

  defp value_side(:coin_margin_futures), do: :quote
  defp value_side(_market), do: :base

  defp price_filter(filters) do
    %{"minPrice" => min, "maxPrice" => max, "tickSize" => tick} =
      find_filter(filters, "PRICE_FILTER")

    {to_decimal(min), to_decimal(max), to_decimal(tick)}
  end

  defp size_filter(filters) do
    %{"minQty" => min, "maxQty" => max, "stepSize" => step} =
      find_filter(filters, "LOT_SIZE")

    {to_decimal(min), to_decimal(max), to_decimal(step)}
  end

  defp notional_filter(filters) do
    case find_filter(filters, "NOTIONAL") || find_filter(filters, "MIN_NOTIONAL") do
      %{"minNotional" => notional} -> to_decimal(notional)
      %{"notional" => notional} -> to_decimal(notional)
      nil -> nil
    end
  end

  defp find_filter(filters, type), do: Enum.find(filters, &(&1["filterType"] == type))
  defp downcase_and_atom(str), do: str |> String.downcase() |> String.to_atom()
  defp to_decimal(val), do: val |> to_string() |> Decimal.new() |> Decimal.normalize()
end
