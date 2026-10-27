defmodule Tai.VenuesAdapters.Deribit.ProductTest do
  use ExUnit.Case, async: true

  alias Tai.VenueAdapters.Deribit.Product

  @base_attrs %{
    instrument_name: "BTC-25SEP20",
    base_currency: "BTC",
    quote_currency: "USD",
    settlement_currency: "BTC",
    instrument_type: "reversed",
    is_active: true,
    kind: "future",
    creation_timestamp: 1_588_838_404_000,
    expiration_timestamp: 1_590_134_400_000,
    min_trade_amount: 0.1,
    tick_size: 0.005,
    contract_size: 10.0,
    maker_commission: 0.004,
    taker_commission: 0.004
  }

  describe ".build/2" do
    test "returns an inverse product from a supported venue instrument" do
      assert {:ok, product} = build()

      assert product.venue_id == :venue_a
      assert product.symbol == :btc_25sep20
      assert product.venue_symbol == "BTC-25SEP20"
      assert product.status == :trading
      assert product.price_increment == Decimal.new("0.005")
      assert product.min_price == Decimal.new("0.005")
      assert product.size_increment == Decimal.new("0.1")
      assert product.min_size == Decimal.new("0.1")
      assert product.value == Decimal.new("1E+1")
      assert product.value_side == :quote
      refute product.is_quanto
      assert product.is_inverse
      assert %DateTime{} = product.listing
      assert %DateTime{} = product.expiry
    end

    test "supports legacy BTC and ETH inverse records without contract metadata" do
      assert {:ok, product} = build(%{instrument_type: nil, settlement_currency: nil})
      assert product.is_inverse
    end

    test "type is :swap for a perpetual future" do
      assert {:ok, product} = build(%{instrument_name: "BTC-PERPETUAL"})
      assert product.type == :swap
    end

    test "assigns maker and taker fees" do
      assert {:ok, product} =
               build(%{maker_commission: "-0.025", taker_commission: "0.05"})

      assert product.maker_fee == Decimal.new("-0.025")
      assert product.taker_fee == Decimal.new("0.05")
    end

    test "rejects unsupported product families and linear contracts" do
      assert {:error, {:unsupported_instrument, {:kind, "spot"}}} = build(%{kind: "spot"})

      assert {:error, {:unsupported_instrument, {:kind, "future_combo"}}} =
               build(%{kind: "future_combo"})

      assert {:error, {:unsupported_instrument, {:kind, "option"}}} =
               build(%{kind: "option", option_type: "call", strike: 10_000.0})

      assert {:error, {:unsupported_instrument, {:contract, "linear", "BTC", "USD", "USDC"}}} =
               build(%{instrument_type: "linear", settlement_currency: "USDC"})
    end

    test "rejects malformed timestamps and non-positive numeric fields" do
      assert {:error, {:invalid_instrument, {:creation_timestamp, -1}}} =
               build(%{creation_timestamp: -1})

      assert {:error, {:invalid_instrument, {:tick_size, 0}}} = build(%{tick_size: 0})
    end

    test "rejects malformed or unexpected instrument names before atom conversion" do
      assert {:error, {:invalid_instrument, {:instrument_name, "BTC-EVIL-PERPETUAL"}}} =
               build(%{instrument_name: "BTC-EVIL-PERPETUAL"})
    end
  end

  defp build(attrs \\ %{}) do
    instrument = struct(ExDeribit.Instrument, Map.merge(@base_attrs, attrs))
    Product.build(instrument, :venue_a)
  end
end
