defmodule ExDeribit.Accounts.Positions do
  alias ExDeribit.HTTPClient

  @type currency :: String.t()
  @type opts :: %{optional(:kind) => String.t()}
  @type position :: ExDeribit.Position.t()
  @type credentials :: ExDeribit.Credentials.t()
  @type result :: {:ok, position} | {:error, term}

  @path "/private/get_positions"

  @spec get(credentials, currency) :: result
  @spec get(credentials, currency, opts) :: result
  def get(credentials, currency, opts \\ %{}) do
    params = Map.put(opts, :currency, currency)

    @path
    |> HTTPClient.auth_get(credentials, params)
    |> parse_response()
  end

  defp parse_response({:ok, %ExDeribit.JsonRpcResponse{result: venue_positions}}) do
    venue_positions
    |> Enum.map(&Mapail.map_to_struct(&1, ExDeribit.Position))
    |> Enum.reduce(
      {:ok, []},
      fn
        {:ok, a}, {:ok, acc} -> {:ok, [a | acc]}
        _, _acc -> {:error, :parse_result_item}
      end
    )
  end
end
