defmodule ExHuobi.Futures.Contracts do
  alias ExHuobi.Futures

  @type contract :: Futures.Contract.t()
  @type error_reason :: term

  @path "/contract_contract_info"

  @spec get :: {:ok, [contract]} | {:error, error_reason}
  def get do
    @path
    |> Futures.HTTPClient.non_auth_get()
    |> parse_response()
  end

  defp parse_response({:ok, %{"status" => "ok", "data" => data}}) when is_list(data) do
    contracts =
      data
      |> Enum.map(&to_struct/1)
      |> Enum.map(fn {:ok, i} -> i end)

    {:ok, contracts}
  end

  defp parse_response({:error, _} = error), do: error

  defp to_struct(data) do
    data
    |> Mapail.map_to_struct(
      ExHuobi.Futures.Contract,
      transformations: [:snake_case]
    )
  end
end
