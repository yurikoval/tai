defmodule Tai.VenueAdapters.Gdax.Products do
  @moduledoc """
  Hydrates the available products on the Coinbase Exchange.
  """

  @type venue :: Tai.Venue.id()
  @type product :: Tai.Venues.Product.t()
  @type error_reason ::
          :timeout
          | {:service_unavailable, reason :: String.t()}
          | {:http_error, status :: non_neg_integer, reason :: term}
          | {:invalid_products_response, :malformed}
          | {:invalid_product, String.t() | nil, term}
          | term

  @spec products(venue) :: {:ok, [product]} | {:error, error_reason}
  def products(venue_id) do
    with {:ok, exchange_products} <- ExGdax.list_products(),
         {:ok, products} <- build_products(exchange_products, venue_id) do
      {:ok, products}
    else
      {:error, reason} when reason in [:timeout, :connect_timeout, "timeout"] ->
        {:error, :timeout}

      {:error, reason, 503} ->
        {:error, {:service_unavailable, reason}}

      {:error, reason, status} ->
        {:error, {:http_error, status, reason}}

      {:error, _reason} = error ->
        error
    end
  end

  defp build_products(exchange_products, venue_id) when is_list(exchange_products) do
    exchange_products
    |> Enum.reduce_while({:ok, []}, fn exchange_product, {:ok, products} ->
      case build(exchange_product, venue_id) do
        {:ok, product} -> {:cont, {:ok, [product | products]}}
        {:error, _reason} = error -> {:halt, error}
      end
    end)
    |> case do
      {:ok, products} -> {:ok, Enum.reverse(products)}
      {:error, _reason} = error -> error
    end
  end

  defp build_products(_exchange_products, _venue_id) do
    {:error, {:invalid_products_response, :malformed}}
  end

  defp build(
         %{
           "base_currency" => base_currency,
           "quote_currency" => quote_currency,
           "id" => id,
           "status" => exchange_status,
           "base_increment" => raw_base_increment,
           "quote_increment" => raw_quote_increment,
           "min_market_funds" => raw_min_market_funds
         },
         venue_id
       ) do
    with {:ok, status} <- Tai.VenueAdapters.Gdax.ProductStatus.normalize(exchange_status),
         {:ok, base_increment} <- cast_decimal(raw_base_increment),
         {:ok, quote_increment} <- cast_decimal(raw_quote_increment),
         {:ok, min_market_funds} <- cast_decimal(raw_min_market_funds) do
      symbol = Tai.Symbol.build(base_currency, quote_currency)

      {:ok,
       %Tai.Venues.Product{
         venue_id: venue_id,
         symbol: symbol,
         venue_symbol: id,
         base: downcase_and_atom(base_currency),
         quote: downcase_and_atom(quote_currency),
         venue_base: base_currency,
         venue_quote: quote_currency,
         status: status,
         type: :spot,
         collateral: false,
         price_increment: quote_increment,
         size_increment: base_increment,
         min_price: quote_increment,
         min_size: base_increment,
         min_notional: min_market_funds,
         max_size: nil,
         value: Decimal.new(1),
         value_side: :base,
         is_quanto: false,
         is_inverse: false
       }}
    else
      {:error, reason} -> {:error, {:invalid_product, id, reason}}
    end
  end

  defp build(product, _venue_id) when is_map(product) do
    {:error, {:invalid_product, Map.get(product, "id"), :malformed}}
  end

  defp build(_product, _venue_id), do: {:error, {:invalid_product, nil, :malformed}}

  defp cast_decimal(value) do
    case Decimal.cast(value) do
      {:ok, decimal} -> {:ok, Decimal.normalize(decimal)}
      :error -> {:error, {:invalid_decimal, value}}
    end
  end

  defp downcase_and_atom(str), do: str |> String.downcase() |> String.to_atom()
end
