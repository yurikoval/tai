defmodule ExOkex.PublicIntegrationTest do
  use ExUnit.Case, async: false
  use ExVCR.Mock, adapter: ExOkex.Test.ExVCRHackney

  alias ExOkex.{Config, Public}
  alias ExOkex.Public.Instrument

  setup_all do
    HTTPoison.start()
    :ok
  end

  setup do
    ExVCR.Config.cassette_library_dir("fixture/vcr_cassettes")

    ExVCR.Config.response_headers_blacklist([
      "set-cookie",
      "etag",
      "cf-request-id",
      "cf-ray"
    ])

    :ok
  end

  test "retrieves current spot, swap, and futures instruments from OKX V5" do
    config = %Config{api_url: "https://www.okx.com"}

    use_cassette "okx_v5/public_instruments", match_requests_on: [:query] do
      assert_instruments(Public.instruments("SPOT", %{instId: "BTC-USDT"}, config), "SPOT")

      assert_instruments(
        Public.instruments("SWAP", %{instId: "BTC-USDT-SWAP"}, config),
        "SWAP"
      )

      assert_instruments(
        Public.instruments("FUTURES", %{instFamily: "BTC-USD"}, config),
        "FUTURES"
      )
    end
  end

  defp assert_instruments({:ok, instruments}, instrument_type) do
    assert [%Instrument{} | _] = instruments
    assert Enum.all?(instruments, &(&1.instrument_type == instrument_type))
    assert Enum.all?(instruments, &(&1.state in ["live", "preopen", "suspend", "post_only"]))
  end
end
