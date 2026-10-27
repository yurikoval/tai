defmodule ExDeribit.HTTPClientTest do
  use ExUnit.Case, async: false

  import Mock

  alias ExDeribit.HTTPClient

  test "returns a typed error for malformed successful JSON" do
    with_response(%HTTPoison.Response{status_code: 200, body: "not-json"}, fn ->
      assert {:error, :invalid_json} = HTTPClient.non_auth_get("/public/test")
    end)
  end

  test "returns a typed error for an invalid JSON-RPC envelope" do
    body = Jason.encode!(%{"result" => []})

    with_response(%HTTPoison.Response{status_code: 200, body: body}, fn ->
      assert {:error, :invalid_json_rpc_response} = HTTPClient.non_auth_get("/public/test")
    end)
  end

  test "preserves Deribit API errors" do
    error = %{"code" => 10_001, "message" => "invalid_params"}
    body = Jason.encode!(%{"jsonrpc" => "2.0", "error" => error})

    with_response(%HTTPoison.Response{status_code: 200, body: body}, fn ->
      assert {:error, {:api_error, ^error}} = HTTPClient.non_auth_get("/public/test")
    end)
  end

  test "returns status and body for non-successful HTTP responses" do
    response = %HTTPoison.Response{status_code: 503, body: "unavailable"}

    with_response(response, fn ->
      assert {:error, {:http_error, 503, "unavailable"}} =
               HTTPClient.non_auth_get("/public/test")
    end)
  end

  defp with_response(response, test) do
    with_mock HTTPoison, request: fn %HTTPoison.Request{} -> {:ok, response} end do
      test.()
    end
  end
end
