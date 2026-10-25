defmodule ExHuobi.Rest.Request do
  @type path :: String.t()
  @type params :: map
  @type message :: String.t()
  @type bad_request :: {:bad_request, error :: map}
  @type service_unavailable :: {:service_unavailable, message}
  @type non_auth_error_reason ::
          :timeout
          | :not_found
          | bad_request
          | :overloaded
          | service_unavailable
  @type non_auth_response :: {:ok, map | [map]} | {:error, non_auth_error_reason}

  def send(request) do
    request
    |> HTTPoison.request()
    |> parse_response
  end

  defp parse_response({:ok, %HTTPoison.Response{status_code: 200, body: body}}) do
    json = Jason.decode!(body)
    {:ok, json}
  end

  defp parse_response({:error, %HTTPoison.Error{reason: :timeout}}) do
    {:error, :timeout}
  end
end
