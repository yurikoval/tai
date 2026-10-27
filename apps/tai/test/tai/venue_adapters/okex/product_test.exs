defmodule Tai.VenuesAdapters.OkEx.ProductTest do
  use ExUnit.Case, async: true

  alias ExOkex.Public.Instrument
  alias Tai.VenueAdapters.OkEx.Product

  describe ".build/2" do
    test "maps a linear futures instrument" do
      product =
        instrument(%{
          alias: "quarter",
          contract_type: "linear",
          contract_value: "0.01",
          contract_value_currency: "BTC",
          expiry_time: "1774598400000",
          instrument_family: "BTC-USDT",
          instrument_id: "BTC-USDT-260327",
          instrument_type: "FUTURES",
          listing_time: "1766736000000",
          underlying: "BTC-USDT"
        })
        |> Product.build(:venue_a)

      assert product.venue_id == :venue_a
      assert product.symbol == :btc_usdt_260327
      assert product.venue_symbol == "BTC-USDT-260327"
      assert product.alias == "quarter"
      assert product.base == :btc
      assert product.quote == :usdt
      assert product.venue_base == "BTC"
      assert product.venue_quote == "USDT"
      assert product.status == :trading
      assert product.type == :future
      assert product.price_increment == Decimal.new("0.1")
      assert product.size_increment == Decimal.new("1")
      assert product.min_size == Decimal.new("1")
      assert product.value == Decimal.new("0.01")
      assert product.value_side == :base
      assert product.listing == DateTime.from_unix!(1_766_736_000_000, :millisecond)
      assert product.expiry == DateTime.from_unix!(1_774_598_400_000, :millisecond)
      refute product.is_inverse
    end

    test "maps an inverse futures instrument" do
      product =
        instrument(%{
          contract_type: "inverse",
          contract_value: "100",
          contract_value_currency: "USD",
          expiry_time: "1774598400000",
          instrument_family: "BTC-USD",
          instrument_id: "BTC-USD-260327",
          instrument_type: "FUTURES",
          underlying: "BTC-USD"
        })
        |> Product.build(:venue_a)

      assert product.value_side == :quote
      assert product.is_inverse
    end

    test "maps a linear perpetual swap and its pre-open state" do
      product =
        instrument(%{
          contract_type: "linear",
          contract_value: "0.01",
          contract_value_currency: "BTC",
          expiry_time: "",
          instrument_family: "BTC-USDT",
          instrument_id: "BTC-USDT-SWAP",
          instrument_type: "SWAP",
          state: "preopen",
          underlying: "BTC-USDT"
        })
        |> Product.build(:venue_a)

      assert product.type == :swap
      assert product.status == :pre_trading
      assert product.expiry == nil
      assert product.value_side == :base
      refute product.is_inverse
    end

    test "maps an inverse perpetual swap" do
      product =
        instrument(%{
          contract_type: "inverse",
          contract_value: "100",
          contract_value_currency: "USD",
          expiry_time: "",
          instrument_family: "BTC-USD",
          instrument_id: "BTC-USD-SWAP",
          instrument_type: "SWAP",
          underlying: "BTC-USD"
        })
        |> Product.build(:venue_a)

      assert product.value_side == :quote
      assert product.is_inverse
    end

    test "maps a spot instrument with V5 decimal and timestamp fields" do
      product =
        instrument(%{
          base_currency: "BTC",
          contract_value: nil,
          contract_value_currency: nil,
          instrument_id: "BTC-USDT",
          instrument_type: "SPOT",
          listing_time: "1606468572000",
          lot_size: "0.00000001",
          minimum_size: "0.00001",
          quote_currency: "USDT",
          tick_size: "0.1"
        })
        |> Product.build(:venue_a)

      assert product.type == :spot
      assert product.symbol == :btc_usdt
      assert product.status == :trading
      assert product.price_increment == Decimal.new("0.1")
      assert product.size_increment == Decimal.new("0.00000001")
      assert product.min_size == Decimal.new("0.00001")
      assert product.value == Decimal.new(1)
      assert product.value_side == :base
      assert product.listing == DateTime.from_unix!(1_606_468_572_000, :millisecond)
      assert product.expiry == nil
      refute product.is_inverse
    end

    test "maps non-live states deliberately" do
      for {venue_state, status} <- [
            {"post_only", :restricted},
            {"suspend", :halt},
            {"settling", :post_trading},
            {"expired", :settled},
            {"new-state", :unknown}
          ] do
        product =
          instrument(%{
            base_currency: "BTC",
            instrument_id: "BTC-USDT",
            instrument_type: "SPOT",
            quote_currency: "USDT",
            state: venue_state
          })
          |> Product.build(:venue_a)

        assert product.status == status
      end
    end
  end

  defp instrument(attrs) do
    defaults = %{
      alias: "",
      base_currency: "",
      contract_type: "",
      contract_value: "",
      contract_value_currency: "",
      expiry_time: "",
      instrument_family: "",
      instrument_id: "",
      instrument_type: "",
      listing_time: "1766736000000",
      lot_size: "1",
      minimum_size: "1",
      quote_currency: "",
      settlement_currency: "",
      state: "live",
      tick_size: "0.1",
      underlying: ""
    }

    struct!(Instrument, Map.merge(defaults, attrs))
  end
end
