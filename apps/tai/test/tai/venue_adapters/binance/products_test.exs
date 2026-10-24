defmodule Tai.VenueAdapters.Binance.ProductsTest do
  use ExUnit.Case, async: false
  import Mock
  alias Tai.VenueAdapters.Binance.Products

  @filters [
    %{
      "filterType" => "PRICE_FILTER",
      "minPrice" => "0.1",
      "maxPrice" => "1000000",
      "tickSize" => "0.1"
    },
    %{
      "filterType" => "LOT_SIZE",
      "minQty" => "0.001",
      "maxQty" => "1000",
      "stepSize" => "0.001"
    }
  ]

  test "discovers spot products with current and legacy notional filters" do
    response = %{
      "symbols" => [
        %{
          "symbol" => "BTCUSDT",
          "status" => "TRADING",
          "baseAsset" => "BTC",
          "quoteAsset" => "USDT",
          "filters" => [
            %{
              "filterType" => "NOTIONAL",
              "minNotional" => "5",
              "maxNotional" => "9000000"
            }
            | @filters
          ]
        },
        %{
          "symbol" => "ETHUSDT",
          "status" => "TRADING",
          "baseAsset" => "ETH",
          "quoteAsset" => "USDT",
          "filters" => [%{"filterType" => "MIN_NOTIONAL", "minNotional" => "10"} | @filters]
        }
      ]
    }

    with_mock ExBinance.Rest.SpotClient,
      get: fn "/api/v3/exchangeInfo", %{} -> {:ok, response} end do
      assert {:ok, [btc, eth]} = Products.products(:binance, :spot)

      assert btc.symbol == :btc_usdt
      assert btc.type == :spot
      assert btc.min_notional == Decimal.new(5)
      refute btc.is_inverse
      assert Decimal.equal?(eth.min_notional, Decimal.new(10))
    end
  end

  test "discovers USD-M perpetual swaps" do
    response = %{
      "symbols" => [
        %{
          "symbol" => "BTCUSDT",
          "pair" => "BTCUSDT",
          "contractType" => "PERPETUAL",
          "deliveryDate" => 4_133_404_800_000,
          "onboardDate" => 1_567_965_300_000,
          "status" => "TRADING",
          "baseAsset" => "BTC",
          "quoteAsset" => "USDT",
          "filters" => [%{"filterType" => "MIN_NOTIONAL", "notional" => "50"} | @filters]
        }
      ]
    }

    with_mock ExBinance.Rest.UsdMarginFuturesClient,
      get: fn "/fapi/v1/exchangeInfo", %{} -> {:ok, response} end do
      assert {:ok, [product]} =
               Products.products(:binance_usd_futures, :usd_margin_futures)

      assert product.symbol == :btcusdt
      assert product.type == :swap
      assert product.expiry == nil
      assert product.value == Decimal.new(1)
      assert product.value_side == :base
      refute product.is_inverse
    end
  end

  test "discovers dated COIN-M futures with contract value" do
    delivery_date = 1_751_046_400_000

    response = %{
      "symbols" => [
        %{
          "symbol" => "BTCUSD_250627",
          "pair" => "BTCUSD",
          "contractType" => "CURRENT_QUARTER",
          "deliveryDate" => delivery_date,
          "onboardDate" => 1_742_681_600_000,
          "contractStatus" => "TRADING",
          "baseAsset" => "BTC",
          "quoteAsset" => "USD",
          "contractSize" => 100,
          "filters" => @filters
        }
      ]
    }

    with_mock ExBinance.Rest.CoinMarginFuturesClient,
      get: fn "/dapi/v1/exchangeInfo", %{} -> {:ok, response} end do
      assert {:ok, [product]} =
               Products.products(:binance_coin_futures, :coin_margin_futures)

      assert product.symbol == :btcusd_250627
      assert product.type == :future
      assert product.expiry == DateTime.from_unix!(delivery_date, :millisecond)
      assert Decimal.equal?(product.value, Decimal.new(100))
      assert product.value_side == :quote
      assert product.is_inverse
    end
  end
end
