defmodule Tai.Venues.Adapters.Gdax.ProductsTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: Tai.Test.ExVCRHackney
  import Mock

  alias Tai.VenueAdapters.Gdax.Products

  @venue Tai.TestSupport.Helpers.test_venue_adapter(:gdax)

  setup_all do
    HTTPoison.start()
    :ok
  end

  test "retrieves current Coinbase Exchange trade rules without credentials" do
    use_cassette "venue_adapters/shared/products/gdax/success" do
      assert {:ok, products} = Tai.Venues.Client.products(@venue)
      assert %Tai.Venues.Product{} = product = find_product_by_symbol(products, :ltc_btc)
      assert product.status == Tai.Venues.ProductStatus.trading()
      assert Decimal.eq?(product.min_notional, "0.000016")
      assert Decimal.eq?(product.min_price, "0.000001")
      assert Decimal.eq?(product.min_size, "0.00000001")
      assert product.max_size == nil
      assert Decimal.eq?(product.price_increment, "0.000001")
      assert Decimal.eq?(product.size_increment, "0.00000001")

      assert Enum.any?(products, fn product ->
               product.status == Tai.Venues.ProductStatus.delisted()
             end)
    end
  end

  test "returns an explicit error for an unknown product status" do
    product = current_product(%{"status" => "offline"})

    with_mock ExGdax, list_products: fn -> {:ok, [product]} end do
      assert Products.products(:gdax) ==
               {:error, {:invalid_product, "BTC-USD", {:unknown_status, "offline"}}}
    end
  end

  test "returns an explicit error for a malformed product" do
    product = Map.delete(current_product(), "base_increment")

    with_mock ExGdax, list_products: fn -> {:ok, [product]} end do
      assert Products.products(:gdax) ==
               {:error, {:invalid_product, "BTC-USD", :malformed}}
    end
  end

  test "returns an explicit error for invalid product identifiers" do
    invalid_products = [
      {current_product(%{"id" => nil}), nil},
      {current_product(%{"id" => 123}), nil},
      {current_product(%{"id" => ""}), nil},
      {current_product(%{"base_currency" => nil}), "BTC-USD"},
      {current_product(%{"base_currency" => 123}), "BTC-USD"},
      {current_product(%{"base_currency" => ""}), "BTC-USD"},
      {current_product(%{"quote_currency" => nil}), "BTC-USD"},
      {current_product(%{"quote_currency" => 123}), "BTC-USD"},
      {current_product(%{"quote_currency" => ""}), "BTC-USD"}
    ]

    Enum.each(invalid_products, fn {product, product_id} ->
      with_mock ExGdax, list_products: fn -> {:ok, [product]} end do
        assert Products.products(:gdax) ==
                 {:error, {:invalid_product, product_id, :malformed}}
      end
    end)
  end

  test "returns an explicit error for a malformed products response" do
    with_mock ExGdax, list_products: fn -> {:ok, nil} end do
      assert Products.products(:gdax) ==
               {:error, {:invalid_products_response, :malformed}}
    end
  end

  test "preserves non-service-unavailable HTTP status codes" do
    with_mock ExGdax, list_products: fn -> {:error, "rate limited", 429} end do
      assert Products.products(:gdax) == {:error, {:http_error, 429, "rate limited"}}
    end
  end

  test "returns an error tuple when the request times out" do
    with_mock ExGdax, list_products: fn -> {:error, :timeout} end do
      assert Products.products(:gdax) == {:error, :timeout}
    end
  end

  test "returns an error tuple when down for maintenance" do
    with_mock ExGdax,
      list_products: fn -> {:error, "Coinbase Exchange is unavailable", 503} end do
      assert Products.products(:gdax) ==
               {:error, {:service_unavailable, "Coinbase Exchange is unavailable"}}
    end
  end

  defp current_product(overrides \\ %{}) do
    Map.merge(
      %{
        "id" => "BTC-USD",
        "base_currency" => "BTC",
        "quote_currency" => "USD",
        "status" => "online",
        "base_increment" => "0.00000001",
        "quote_increment" => "0.01",
        "min_market_funds" => "1"
      },
      overrides
    )
  end

  defp find_product_by_symbol(products, symbol) do
    Enum.find(products, &(&1.symbol == symbol))
  end
end
