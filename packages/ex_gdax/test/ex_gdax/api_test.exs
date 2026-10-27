defmodule ExGdax.ApiTest do
  use ExUnit.Case, async: false
  import Mock

  alias ExGdax.{Api, Config}

  @config %Config{
    api_key: "key",
    api_secret: Base.encode64("secret"),
    api_passphrase: "passphrase",
    api_url: "https://example.com"
  }

  test "public GET requests omit authentication headers and work without credentials" do
    config = %{@config | api_key: nil, api_secret: nil, api_passphrase: nil}

    with_mock HTTPoison,
      get: fn "https://example.com/products", headers ->
        send(self(), {:headers, headers})
        {:ok, %HTTPoison.Response{status_code: 200, body: ~s([{"id":"BTC-USD"}])}}
      end do
      assert Api.public_get("/products", %{}, config) == {:ok, [%{"id" => "BTC-USD"}]}
      assert_receive {:headers, headers}

      refute Enum.any?(headers, fn {name, _value} ->
               name |> to_string() |> String.starts_with?("CB-ACCESS-")
             end)
    end
  end

  test "authenticated request timestamps are strings" do
    with_mock HTTPoison,
      get: fn "https://example.com/accounts", headers ->
        send(self(), {:headers, headers})
        {:ok, %HTTPoison.Response{status_code: 200, body: "[]"}}
      end do
      assert Api.get("/accounts", %{}, @config) == {:ok, []}
      assert_receive {:headers, headers}
      assert is_binary(headers[:"CB-ACCESS-TIMESTAMP"])
    end
  end

  test "normalizes HTTP, transport, and invalid JSON errors" do
    with_mock HTTPoison,
      get: fn
        "https://example.com/unavailable", _headers ->
          {:ok,
           %HTTPoison.Response{
             status_code: 503,
             body: ~s({"message":"service unavailable"})
           }}

        "https://example.com/invalid-json", _headers ->
          {:ok, %HTTPoison.Response{status_code: 200, body: "not json"}}

        "https://example.com/timeout", _headers ->
          {:error, %HTTPoison.Error{reason: :timeout}}
      end do
      assert Api.public_get("/unavailable", %{}, @config) ==
               {:error, "service unavailable", 503}

      assert Api.public_get("/invalid-json", %{}, @config) ==
               {:error, {:invalid_json, "not json"}}

      assert Api.public_get("/timeout", %{}, @config) == {:error, :timeout}
    end
  end

  test "uses the current Coinbase Exchange REST host by default" do
    previous = Application.get_env(:ex_gdax, :api_url)
    Application.delete_env(:ex_gdax, :api_url)

    on_exit(fn ->
      if previous do
        Application.put_env(:ex_gdax, :api_url, previous)
      else
        Application.delete_env(:ex_gdax, :api_url)
      end
    end)

    assert Config.api_url() == "https://api.exchange.coinbase.com"
  end
end
