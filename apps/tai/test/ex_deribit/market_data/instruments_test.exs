defmodule ExDeribit.MarketData.InstrumentsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mock

  alias ExDeribit.MarketData.Instruments

  @valid_instrument %{
    "instrument_name" => "BTC-PERPETUAL",
    "base_currency" => "BTC",
    "quote_currency" => "USD",
    "settlement_currency" => "BTC",
    "instrument_type" => "reversed",
    "is_active" => true,
    "state" => "open",
    "kind" => "future",
    "creation_timestamp" => 1_588_838_404_000,
    "expiration_timestamp" => 4_133_404_800_000,
    "min_trade_amount" => 10,
    "tick_size" => 0.5,
    "contract_size" => 10,
    "maker_commission" => 0,
    "taker_commission" => 0.0005
  }

  test "accepts the complete catalogue query model" do
    response = %ExDeribit.JsonRpcResponse{result: [@valid_instrument]}

    with_mock ExDeribit.HTTPClient,
      non_auth_get: fn "/public/get_instruments", params ->
        assert params == %{currency: "any", expired: false, kind: :future}
        {:ok, response}
      end do
      assert {:ok, [instrument]} =
               Instruments.get("any", %{kind: :future, expired: false})

      assert instrument.instrument_name == "BTC-PERPETUAL"
      assert instrument.instrument_type == "reversed"
    end
  end

  test "validates currency and option types without making a request" do
    assert {:error, {:invalid_currency, nil}} = Instruments.get(nil)
    assert {:error, {:invalid_options, []}} = Instruments.get("BTC", [])

    assert {:error, {:invalid_option, :kind, :unknown}} =
             Instruments.get("BTC", %{kind: :unknown})

    assert {:error, {:invalid_option, :expired, "false"}} =
             Instruments.get("BTC", %{expired: "false"})

    assert {:error, {:invalid_option, :limit, 10}} = Instruments.get("BTC", %{limit: 10})
  end

  test "returns a typed error for a non-list result" do
    response = %ExDeribit.JsonRpcResponse{result: %{}}

    with_mock ExDeribit.HTTPClient,
      non_auth_get: fn "/public/get_instruments", %{currency: "any"} -> {:ok, response} end do
      assert {:error, {:invalid_result, %{}}} = Instruments.get("any")
    end
  end

  test "ignores incomplete and incorrectly typed catalogue items" do
    response = %ExDeribit.JsonRpcResponse{
      result: [
        @valid_instrument,
        %{"instrument_name" => "BTC-PERPETUAL"},
        Map.put(@valid_instrument, "is_active", "true"),
        "malformed"
      ]
    }

    log =
      capture_log(fn ->
        with_mock ExDeribit.HTTPClient,
          non_auth_get: fn "/public/get_instruments", %{currency: "any"} ->
            {:ok, response}
          end do
          assert {:ok, [%ExDeribit.Instrument{instrument_name: "BTC-PERPETUAL"}]} =
                   Instruments.get("any")
        end
      end)

    assert log =~ "Deribit ignored malformed instrument at index 1"
    assert log =~ "Deribit ignored malformed instrument at index 2"
    assert log =~ "Deribit ignored malformed instrument at index 3"
  end
end
