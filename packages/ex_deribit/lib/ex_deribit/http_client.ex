defmodule ExDeribit.HTTPClient do
  @type verb :: :get | :post | :put | :delete
  @type params :: map
  @type path :: String.t()
  @type uri :: String.t()
  @type credentials :: ExDeribit.Credentials.t()
  @type non_auth_response :: term
  @type auth_response :: term

  @spec protocol :: String.t()
  def protocol, do: Application.get_env(:ex_deribit, :protocol, "https://")

  @spec domain :: String.t()
  def domain, do: Application.get_env(:ex_deribit, :domain, "www.deribit.com")

  @spec api_path :: String.t()
  def api_path, do: Application.get_env(:ex_deribit, :api_path, "/api/v2")

  @spec origin :: String.t()
  def origin, do: protocol() <> domain()

  @spec auth_get(path, credentials, params) :: auth_response
  def auth_get(path, credentials, params) do
    auth_request(:get, path |> to_uri(params), credentials)
  end

  @spec non_auth_get(path, params) :: non_auth_response
  def non_auth_get(path, params \\ %{}) do
    non_auth_request(:get, path |> to_uri(params))
  end

  @spec auth_request(verb, uri, credentials) :: auth_response
  def auth_request(verb, uri, credentials) do
    body = ""

    headers =
      verb
      |> auth_headers(uri, body, credentials)
      |> put_content_type(:json)

    %HTTPoison.Request{
      method: verb,
      url: url(uri),
      headers: headers,
      body: body
    }
    |> send
  end

  @spec non_auth_request(verb, uri) :: non_auth_response
  def non_auth_request(verb, uri) do
    headers = [] |> put_content_type(:json)

    %HTTPoison.Request{
      method: verb,
      url: url(uri),
      headers: headers
    }
    |> send
  end

  @spec url(uri :: String.t()) :: String.t()
  def url(uri), do: origin() <> uri

  defp to_uri(path, params) do
    %URI{
      path: "#{api_path()}#{path}",
      query: URI.encode_query(params)
    }
    |> URI.to_string()
  end

  defp put_content_type(headers, :json) do
    Keyword.put(headers, :"Content-Type", "application/json")
  end

  defp send(request) do
    request
    |> HTTPoison.request()
    |> parse_response
  end

  defp auth_headers(http_method, uri, request_body, credentials) do
    nonce = ExDeribit.Auth.nonce()
    normalized_http_method = http_method |> normalize_http_method
    timestamp = ExDeribit.Auth.timestamp()

    signature =
      ExDeribit.Auth.sign_http(
        credentials.client_secret,
        timestamp,
        nonce,
        normalized_http_method,
        uri,
        request_body
      )

    [
      Authorization:
        [
          "deri-hmac-sha256 id=#{credentials.client_id}",
          "ts=#{timestamp}",
          "nonce=#{nonce}",
          "sig=#{signature}"
        ]
        |> Enum.join(",")
    ]
  end

  defp normalize_http_method(:get), do: "GET"
  defp normalize_http_method(:post), do: "POST"
  defp normalize_http_method(:put), do: "PUT"
  defp normalize_http_method(:delete), do: "DELETE"

  defp parse_response({:ok, %HTTPoison.Response{status_code: 200, body: body}}) do
    {:ok, json} = Jason.decode(body)

    {:ok, rpc_response} =
      Mapail.map_to_struct(json, ExDeribit.JsonRpcResponse, transformations: [:snake_case])

    {:ok, rpc_response}
  end
end
