defmodule Tai.VenueAdapters.Deribit.ProductsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mock

  alias Tai.VenueAdapters.Deribit.Products

  @valid_attrs %{
    instrument_name: "BTC-PERPETUAL",
    base_currency: "BTC",
    quote_currency: "USD",
    settlement_currency: "BTC",
    instrument_type: "reversed",
    is_active: true,
    kind: "future",
    creation_timestamp: 1_588_838_404_000,
    expiration_timestamp: 4_133_404_800_000,
    min_trade_amount: 10,
    tick_size: 0.5,
    contract_size: 10,
    maker_commission: 0,
    taker_commission: 0.0005
  }

  test "hydrates supported products from one complete catalogue request" do
    instruments = [
      instrument(),
      instrument(%{
        instrument_name: "AAVE_USDC",
        base_currency: "AAVE",
        quote_currency: "USDC",
        settlement_currency: "USDC",
        instrument_type: "linear",
        kind: "spot"
      }),
      instrument(%{instrument_name: nil})
    ]

    log =
      capture_log(fn ->
        with_mock ExDeribit.MarketData.Instruments,
          get: fn "any", %{expired: false} -> {:ok, instruments} end do
          assert {:ok, [product]} = Products.products(:deribit)
          assert product.symbol == :btc_perpetual
          assert called(ExDeribit.MarketData.Instruments.get("any", %{expired: false}))
        end
      end)

    assert log =~ "Deribit ignored instrument \"AAVE_USDC\""
    assert log =~ "Deribit ignored instrument nil"
  end

  test "returns an error when the catalogue contains no supported products" do
    instruments = [instrument(%{kind: "option"}), instrument(%{kind: "spot"})]

    with_mock ExDeribit.MarketData.Instruments,
      get: fn "any", %{expired: false} -> {:ok, instruments} end do
      assert capture_log(fn ->
               assert {:error, :no_supported_instruments} = Products.products(:deribit)
             end)
    end
  end

  test "preserves catalogue request errors" do
    with_mock ExDeribit.MarketData.Instruments,
      get: fn "any", %{expired: false} -> {:error, :unavailable} end do
      assert {:error, :unavailable} = Products.products(:deribit)
    end
  end

  defp instrument(attrs \\ %{}) do
    struct(ExDeribit.Instrument, Map.merge(@valid_attrs, attrs))
  end
end
