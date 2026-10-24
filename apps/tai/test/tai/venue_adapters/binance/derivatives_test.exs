defmodule Tai.VenueAdapters.Binance.DerivativesTest do
  use ExUnit.Case, async: false
  import Mock
  alias Tai.VenueAdapters.Binance.{Accounts, Positions}

  @credentials %{api_key: "key", secret_key: "secret"}

  test "normalizes USD-M account balances" do
    response = %{
      "assets" => [
        %{
          "asset" => "USDT",
          "marginBalance" => "125.5",
          "availableBalance" => "100.25"
        }
      ],
      "positions" => []
    }

    with_mock ExBinance.Rest.UsdMarginFuturesClient,
      get: fn "/fapi/v3/account", %{}, _credentials -> {:ok, response} end do
      assert {:ok, [account]} =
               Accounts.accounts(:binance_usd_futures, :main, @credentials, :usd_margin_futures)

      assert account.asset == :usdt
      assert account.type == "usd_margin_futures"
      assert account.equity == Decimal.new("125.5")
      assert account.free == Decimal.new("100.25")
      assert account.locked == Decimal.new("25.25")
    end
  end

  test "normalizes COIN-M account balances" do
    response = %{
      "assets" => [
        %{
          "asset" => "BTC",
          "marginBalance" => "1.25",
          "availableBalance" => "1.0"
        }
      ],
      "positions" => []
    }

    with_mock ExBinance.Rest.CoinMarginFuturesClient,
      get: fn "/dapi/v1/account", %{}, _credentials -> {:ok, response} end do
      assert {:ok, [account]} =
               Accounts.accounts(
                 :binance_coin_futures,
                 :main,
                 @credentials,
                 :coin_margin_futures
               )

      assert account.asset == :btc
      assert account.type == "coin_margin_futures"
      assert account.locked == Decimal.new("0.25")
    end
  end

  test "rejects hedge-mode positions that Tai cannot store safely" do
    response = %{
      "assets" => [],
      "positions" => [
        %{
          "symbol" => "BTCUSDT",
          "positionAmt" => "0.5",
          "entryPrice" => "60000",
          "leverage" => "10",
          "positionSide" => "LONG"
        },
        %{
          "symbol" => "BTCUSDT",
          "positionAmt" => "0.25",
          "entryPrice" => "61000",
          "leverage" => "10",
          "positionSide" => "SHORT"
        }
      ]
    }

    with_mock ExBinance.Rest.UsdMarginFuturesClient,
      get: fn "/fapi/v3/account", %{}, _credentials -> {:ok, response} end do
      assert {:error, {:unhandled, :hedge_mode_not_supported}} =
               Positions.positions(
                 :binance_usd_futures,
                 :main,
                 @credentials,
                 :usd_margin_futures
               )
    end
  end

  test "normalizes long and short derivative positions" do
    response = %{
      "assets" => [],
      "positions" => [
        %{
          "symbol" => "BTCUSDT",
          "positionAmt" => "0.5",
          "entryPrice" => "60000",
          "leverage" => "10",
          "isolated" => false,
          "positionSide" => "BOTH"
        },
        %{
          "symbol" => "ETHUSDT",
          "positionAmt" => "-2",
          "entryPrice" => "2500",
          "leverage" => "5",
          "marginType" => "isolated",
          "positionSide" => "BOTH"
        },
        %{
          "symbol" => "XRPUSDT",
          "positionAmt" => "0",
          "entryPrice" => "0",
          "leverage" => "5",
          "positionSide" => "BOTH"
        }
      ]
    }

    with_mock ExBinance.Rest.UsdMarginFuturesClient,
      get: fn "/fapi/v3/account", %{}, _credentials -> {:ok, response} end do
      assert {:ok, [long, short]} =
               Positions.positions(
                 :binance_usd_futures,
                 :main,
                 @credentials,
                 :usd_margin_futures
               )

      assert long.product_symbol == :btcusdt
      assert long.side == :long
      assert long.qty == Decimal.new("0.5")
      assert long.margin_mode == :crossed

      assert short.product_symbol == :ethusdt
      assert short.side == :short
      assert short.qty == Decimal.new(2)
      assert short.margin_mode == :fixed
    end
  end
end
