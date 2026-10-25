defmodule ExDeltaExchange.HTTPClient do
  alias ExDeltaExchange.JsonResponse

  @type verb :: :get | :post | :put | :delete
  @type path :: String.t()
  @type query_params :: map
  @type request_body :: String.t()
  @type credentials :: ExDeltaExchange.Credentials.t()
  @type error_reason :: Maptu.Extension.non_strict_error_reason() | HTTPoison.Error.t()
  @type response :: {:ok, JsonResponse.t()} | {:error, error_reason}

  @spec domain :: String.t()
  def domain, do: Application.get_env(:ex_delta_exchange, :domain, "api.delta.exchange")

  @spec protocol :: String.t()
  def protocol, do: Application.get_env(:ex_delta_exchange, :protocol, "https://")

  @spec origin :: String.t()
  def origin, do: protocol() <> domain()

  @spec url(path) :: String.t()
  def url(path), do: origin() <> api_path() <> path

  @spec api_path :: String.t()
  def api_path, do: Application.get_env(:ex_delta_exchange, :api_path, "/v2")

  @spec get(path, query_params) :: response
  def get(path, query_params) do
    non_auth_request(:get, path, query_params, "")
  end

  @spec get(path, query_params, credentials) :: response
  def get(path, query_params, credentials) do
    auth_request(:get, path, query_params, "", credentials)
  end

  @spec auth_request(verb, path, query_params, request_body, credentials) :: response
  def auth_request(verb, path, query_params, request_body, credentials) do
    headers =
      verb
      |> auth_headers(path, query_params, request_body, credentials)
      |> put_content_type(:json)

    %HTTPoison.Request{
      method: verb,
      url: url(path),
      headers: headers,
      body: request_body
    }
    |> HTTPoison.request()
    |> parse_response()
  end

  @spec non_auth_request(verb, path, query_params, request_body) :: response
  def non_auth_request(verb, path, _query_params, request_body) do
    headers = [] |> put_content_type(:json)

    %HTTPoison.Request{
      method: verb,
      url: url(path),
      headers: headers,
      body: request_body
    }
    |> HTTPoison.request()
    |> parse_response()
  end

  defp put_content_type(headers, :json) do
    Keyword.put(headers, :"Content-Type", "application/json")
  end

  defp auth_headers(http_method, path, query_params, request_body, credentials) do
    normalized_http_method = http_method |> normalize_http_method
    timestamp = ExDeltaExchange.Auth.timestamp()
    query_string = URI.encode_query(query_params)

    signature =
      ExDeltaExchange.Auth.sign(
        normalized_http_method,
        timestamp,
        api_path() <> path,
        query_string,
        request_body,
        credentials.api_secret
      )

    ["api-key": credentials.api_key, signature: signature, timestamp: timestamp]
  end

  defp normalize_http_method(:get), do: "GET"
  defp normalize_http_method(:post), do: "POST"
  defp normalize_http_method(:put), do: "PUT"
  defp normalize_http_method(:delete), do: "DELETE"

  defp parse_response({:ok, %HTTPoison.Response{body: body}}) do
    {:ok, json} = Jason.decode(body)
    Mapail.map_to_struct(json, JsonResponse, transformations: [:snake_case])
  end

  defp parse_response({:error, _} = result) do
    result
  end
end
