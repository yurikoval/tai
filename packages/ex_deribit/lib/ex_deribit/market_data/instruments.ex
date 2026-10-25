defmodule ExDeribit.MarketData.Instruments do
  alias ExDeribit.HTTPClient

  @type currency :: String.t()
  @type opts :: %{
          optional(:kind) => :future | :option,
          optional(:expired) => boolean
        }
  @type instrument :: ExDeribit.Instrument.t()
  @type result :: {:ok, [instrument]} | {:error, :parse_result_item}

  @path "/public/get_instruments"
  @currencies ~w(BTC ETH)

  @spec get(currency) :: result
  @spec get(currency, opts) :: result
  def get(currency, opts \\ %{}) when currency in @currencies do
    params = Map.put(opts, :currency, currency)

    @path
    |> HTTPClient.non_auth_get(params)
    |> parse_response()
  end

  defp parse_response({:ok, %ExDeribit.JsonRpcResponse{result: venue_instruments}}) do
    venue_instruments
    |> Enum.map(&Mapail.map_to_struct(&1, ExDeribit.Instrument))
    |> Enum.reduce(
      {:ok, []},
      fn
        {:ok, i}, {:ok, acc} -> {:ok, [i | acc]}
        _, _acc -> {:error, :parse_result_item}
      end
    )
  end
end
