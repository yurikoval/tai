defmodule ExDeribit.MarketData.Currencies do
  alias ExDeribit.HTTPClient

  @type currency :: ExDeribit.Currency.t()
  @type result :: {:ok, [currency]} | {:error, :parse_result_item}

  @path "/public/get_currencies"

  @spec get :: result
  def get do
    @path
    |> HTTPClient.non_auth_get()
    |> parse_response()
  end

  defp parse_response({:ok, %ExDeribit.JsonRpcResponse{result: venue_currencies}}) do
    venue_currencies
    |> Enum.map(&Mapail.map_to_struct(&1, ExDeribit.Currency))
    |> Enum.reduce(
      {:ok, []},
      fn
        {:ok, i}, {:ok, acc} -> {:ok, [i | acc]}
        _, _acc -> {:error, :parse_result_item}
      end
    )
  end
end
