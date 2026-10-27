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
    state: "open",
    kind: "future",
    creation_timestamp: 1_588_838_404_000,
    expiration_timestamp: 1_601_020_800_000,
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
      assert DateTime.compare(product.expiry, ~U[2020-09-25 08:00:00Z]) == :eq
    end

    test "rejects inverse records without explicit contract metadata" do
      assert {:error, {:unsupported_instrument, {:contract, nil, "BTC", "USD", nil}}} =
               build(%{instrument_type: nil, settlement_currency: nil})
    end

    test "perpetual futures are swaps without expiry" do
      assert {:ok, product} = build(%{instrument_name: "BTC-PERPETUAL"})
      assert product.type == :swap
      assert product.expiry == nil
    end

    test "maps vanilla options" do
      for {suffix, option_type} <- [{"C", :call}, {"P", :put}] do
        assert {:ok, product} =
                 build(%{
                   kind: "option",
                   instrument_name: "BTC-25SEP20-10000-#{suffix}",
                   quote_currency: "BTC",
                   option_type: Atom.to_string(option_type),
                   strike: 10_000.0,
                   contract_size: 1.0
                 })

        assert product.type == :option
        assert product.payoff_type == :vanilla
        assert product.option_type == option_type
        assert product.strike == Decimal.new("1E+4")
        assert product.value == Decimal.new("1")
        assert product.value_side == :base
        assert product.quote == :btc
        assert DateTime.compare(product.expiry, ~U[2020-09-25 08:00:00Z]) == :eq
      end
    end

    test "rejects malformed option metadata" do
      assert {:error, {:invalid_instrument, {:instrument_name, "BTC-25SEP20-1.2.3-C"}}} =
               build(%{
                 kind: "option",
                 instrument_name: "BTC-25SEP20-1.2.3-C",
                 quote_currency: "BTC",
                 option_type: "call",
                 strike: 1.2
               })

      assert {:error, {:invalid_instrument, {:option_type, "binary"}}} =
               build(%{
                 kind: "option",
                 instrument_name: "BTC-25SEP20-10000-C",
                 quote_currency: "BTC",
                 option_type: "binary"
               })

      assert {:error, {:invalid_instrument, {:strike, 0}}} =
               build(%{
                 kind: "option",
                 instrument_name: "BTC-25SEP20-10000-C",
                 quote_currency: "BTC",
                 option_type: "call",
                 strike: 0
               })

      assert {:error, {:invalid_instrument, {:option_type, "put"}}} =
               build(%{
                 kind: "option",
                 instrument_name: "BTC-25SEP20-10000-C",
                 quote_currency: "BTC",
                 option_type: "put",
                 strike: 10_000
               })

      assert {:error, {:invalid_instrument, {:strike, 11_000}}} =
               build(%{
                 kind: "option",
                 instrument_name: "BTC-25SEP20-10000-C",
                 quote_currency: "BTC",
                 option_type: "call",
                 strike: 11_000
               })
    end

    test "only active open instruments are trading" do
      assert {:ok, locked} = build(%{state: "locked"})
      assert locked.status == :halt

      assert {:ok, inactive} = build(%{is_active: false})
      assert inactive.status == :halt
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

      assert {:error, {:unsupported_instrument, {:contract, "linear", "BTC", "USD", "USDC"}}} =
               build(%{instrument_type: "linear", settlement_currency: "USDC"})
    end

    test "rejects malformed timestamps and non-positive numeric fields" do
      assert {:error, {:invalid_instrument, {:creation_timestamp, -1}}} =
               build(%{creation_timestamp: -1})

      assert {:error, {:invalid_instrument, {:tick_size, 0}}} = build(%{tick_size: 0})
    end

    test "rejects malformed, impossible, and mismatched expiry names before atom conversion" do
      assert {:error, {:invalid_instrument, {:instrument_name, "BTC-EVIL-PERPETUAL"}}} =
               build(%{instrument_name: "BTC-EVIL-PERPETUAL"})

      assert {:error, {:invalid_instrument, {:instrument_name, "BTC-31FEB20"}}} =
               build(%{instrument_name: "BTC-31FEB20"})

      assert {:error, {:invalid_instrument, {:expiration_timestamp, 1_590_134_400_000}}} =
               build(%{expiration_timestamp: 1_590_134_400_000})

      assert {:error, {:invalid_instrument, {:expiration_timestamp, 1_600_992_000_000}}} =
               build(%{expiration_timestamp: 1_600_992_000_000})
    end
  end

  defp build(attrs \\ %{}) do
    instrument = struct(ExDeribit.Instrument, Map.merge(@base_attrs, attrs))
    Product.build(instrument, :venue_a)
  end
end
