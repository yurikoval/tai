defmodule ExDeltaExchange.Auth do
  @type api_secret :: ExDeltaExchange.Credentials.api_secret()

  @spec timestamp :: integer
  def timestamp, do: DateTime.utc_now() |> DateTime.to_unix(:second)

  @spec sign(String.t(), integer, String.t(), String.t(), String.t(), api_secret) :: String.t()
  def sign(verb, ts, path, query_string, request_body, api_secret) do
    payload = "#{verb}#{ts}#{path}#{query_string}#{request_body}"

    :hmac
    |> :crypto.mac(:sha256, api_secret, payload)
    |> Base.encode16(case: :lower)
  end
end
