defmodule ExHuobi.Rest.HTTPClient do
  defmacro __using__(_) do
    quote location: :keep do
      alias ExHuobi.Rest.Request

      @callback rest_protocol :: String.t()
      @callback domain :: String.t()
      @callback origin :: String.t()
      @callback api_path :: String.t()

      @type verb :: :get | :post | :put | :delete
      @type path :: Request.path()
      @type params :: Request.params()
      @type non_auth_response :: Request.non_auth_response()

      @spec non_auth_get(path, params) :: non_auth_response
      def non_auth_get(path, params \\ %{}) do
        non_auth_request(:get, path, params)
      end

      @spec non_auth_request(verb, path, params) :: non_auth_response
      def non_auth_request(verb, path, params) do
        body = Jason.encode!(params)
        headers = [] |> put_content_type(:json)

        %HTTPoison.Request{
          method: verb,
          url: path |> url,
          headers: headers,
          body: body
        }
        |> Request.send()
      end

      @spec url(path) :: String.t()
      def url(path), do: origin() <> api_path() <> path

      defp put_content_type(headers, :json) do
        Keyword.put(headers, :"Content-Type", "application/json")
      end
    end
  end
end
