defmodule ExDeribit.Accounts.Summary do
  alias ExDeribit.HTTPClient

  @type currency :: String.t()
  @type account_summary :: ExDeribit.AccountSummary.t()
  @type result :: {:ok, account_summary} | {:error, term}
  @type credentials :: ExDeribit.Credentials.t()

  @path "/private/get_account_summary"

  @spec get(credentials, currency) :: result
  def get(credentials, currency) do
    @path
    |> HTTPClient.auth_get(credentials, %{currency: currency})
    |> parse_response()
  end

  defp parse_response({:ok, %ExDeribit.JsonRpcResponse{result: venue_summary}}) do
    Mapail.map_to_struct(venue_summary, ExDeribit.AccountSummary)
  end
end
