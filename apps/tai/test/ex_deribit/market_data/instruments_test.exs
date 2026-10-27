defmodule ExDeribit.MarketData.InstrumentsTest do
  use ExUnit.Case, async: false

  import ExUnit.CaptureLog
  import Mock

  alias ExDeribit.MarketData.Instruments

  test "accepts the complete catalogue query model" do
    response = %ExDeribit.JsonRpcResponse{
      result: [
        %{
          "instrument_name" => "BTC-PERPETUAL",
          "kind" => "future",
          "instrument_type" => "reversed"
        }
      ]
    }

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

  test "ignores an individually malformed catalogue item" do
    response = %ExDeribit.JsonRpcResponse{
      result: [%{"instrument_name" => "BTC-PERPETUAL"}, "malformed"]
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
  end
end
