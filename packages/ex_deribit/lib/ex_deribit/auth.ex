defmodule ExDeribit.Auth do
  def sign(client_secret, timestamp, nonce, data) do
    string_to_sign = [timestamp, nonce, data] |> Enum.join("\n")

    :hmac
    |> :crypto.mac(:sha256, client_secret, string_to_sign)
    |> Base.encode16()
  end

  def sign_http(client_secret, timestamp, nonce, http_method, uri, body) do
    request_data = [http_method, uri, body, ""] |> Enum.join("\n")
    sign(client_secret, timestamp, nonce, request_data)
  end

  def nonce, do: :crypto.strong_rand_bytes(4) |> Base.encode16()
  def timestamp, do: :os.system_time(:millisecond)
end
