defmodule ExOkex.PublicTest do
  use ExUnit.Case, async: false

  import Mock

  alias ExOkex.{Api, Config, Public}
  alias ExOkex.Public.Instrument

  @instrument %{
    "alias" => "",
    "baseCcy" => "BTC",
    "ctType" => "",
    "ctVal" => "",
    "ctValCcy" => "",
    "expTime" => "",
    "instFamily" => "",
    "instId" => "BTC-USDT",
    "instType" => "SPOT",
    "listTime" => "1606468572000",
    "lotSz" => "0.00000001",
    "minSz" => "0.00001",
    "quoteCcy" => "USDT",
    "settleCcy" => "",
    "state" => "live",
    "tickSz" => "0.1",
    "uly" => ""
  }

  test "requests and parses V5 instruments" do
    config = %Config{api_url: "https://www.okx.com"}

    with_mock ExOkex.Api.Public,
      get: fn path, params, request_config ->
        assert path == "/api/v5/public/instruments"
        assert params == %{instId: "BTC-USDT", instType: "SPOT"}
        assert request_config == config

        {:ok, %{"code" => "0", "data" => [@instrument], "msg" => ""}}
      end do
      assert {:ok, [%Instrument{} = instrument]} =
               Public.instruments("SPOT", %{instId: "BTC-USDT"}, config)

      assert instrument.instrument_id == "BTC-USDT"
      assert instrument.instrument_type == "SPOT"
      assert instrument.expiry_time == ""
      assert instrument.minimum_size == "0.00001"
    end
  end

  test "uses an explicitly configured API URL as the public URL fallback" do
    previous_api_url = Application.get_env(:ex_okex, :api_url)
    previous_public_api_url = Application.get_env(:ex_okex, :public_api_url)

    on_exit(fn ->
      restore_env(:api_url, previous_api_url)
      restore_env(:public_api_url, previous_public_api_url)
    end)

    Application.put_env(:ex_okex, :api_url, "https://okx-proxy.example")
    Application.delete_env(:ex_okex, :public_api_url)

    with_mock ExOkex.Api.Public,
      get: fn _, _, request_config ->
        assert request_config.api_url == "https://okx-proxy.example"
        {:ok, %{"code" => "0", "data" => [@instrument], "msg" => ""}}
      end do
      assert {:ok, [%Instrument{}]} = Public.instruments("SPOT")
    end
  end

  test "returns OKX application errors" do
    with_mock ExOkex.Api.Public,
      get: fn _, _, _ -> {:ok, %{"code" => "51000", "data" => [], "msg" => "bad request"}} end do
      assert Public.instruments("SPOT") == {:error, {"51000", "bad request"}}
    end
  end

  test "returns an error for malformed successful JSON" do
    response = %HTTPoison.Response{body: "not json", status_code: 200}

    assert Api.parse_response({:ok, response}) == {:error, "not json", 200}
  end

  test "rejects malformed response envelopes" do
    with_mock ExOkex.Api.Public,
      get: fn _, _, _ -> {:ok, %{"code" => "0"}} end do
      assert Public.instruments("SPOT") ==
               {:error, {:invalid_response, %{"code" => "0"}}}
    end
  end

  test "rejects malformed instruments" do
    with_mock ExOkex.Api.Public,
      get: fn _, _, _ -> {:ok, %{"code" => "0", "data" => [%{"instId" => "BTC-USDT"}]}} end do
      assert Public.instruments("SPOT") ==
               {:error, {:invalid_instrument, %{"instId" => "BTC-USDT"}}}
    end
  end

  test "rejects instrument fields that product hydration cannot safely consume" do
    assert {:ok, %Instrument{}} = Instrument.new(future(%{}))

    invalid_instruments = [
      Map.put(@instrument, "alias", []),
      Map.put(@instrument, "listTime", String.duplicate("9", 100)),
      Map.put(@instrument, "lotSz", "not-a-decimal"),
      Map.put(@instrument, "lotSz", "0"),
      Map.put(@instrument, "minSz", "0.0"),
      Map.put(@instrument, "tickSz", "00.000"),
      future(%{"expTime" => ""}),
      future(%{"uly" => "BTC-USDT-EXTRA"}),
      future(%{"ctVal" => "0"})
    ]

    Enum.each(invalid_instruments, fn invalid ->
      assert Instrument.new(invalid) == {:error, {:invalid_instrument, invalid}}
    end)
  end

  test "rejects unsupported instrument types before making a request" do
    assert Public.instruments("OPTION") == {:error, {:invalid_instrument_type, "OPTION"}}
  end

  defp future(overrides) do
    @instrument
    |> Map.merge(%{
      "alias" => "quarter",
      "baseCcy" => "",
      "ctType" => "linear",
      "ctVal" => "0.01",
      "ctValCcy" => "BTC",
      "expTime" => "1774598400000",
      "instFamily" => "BTC-USDT",
      "instId" => "BTC-USDT-260327",
      "instType" => "FUTURES",
      "quoteCcy" => "",
      "settleCcy" => "USDT",
      "uly" => "BTC-USDT"
    })
    |> Map.merge(overrides)
  end

  defp restore_env(key, nil), do: Application.delete_env(:ex_okex, key)
  defp restore_env(key, value), do: Application.put_env(:ex_okex, key, value)
end
