defmodule ExDeltaExchange.Indices.List do
  @type market :: ExDeltaExchange.Index.t()
  @type result :: {:ok, [market]} | {:error, :parse_result_item}

  @spec get() :: result
  def get do
    "/indices"
    |> ExDeltaExchange.HTTPClient.get(%{})
    |> parse_response()
  end

  defp parse_response({:ok, %ExDeltaExchange.JsonResponse{success: true, result: assets}}) do
    assets
    |> Enum.map(&Mapail.map_to_struct(&1, ExDeltaExchange.Index, transformations: [:snake_case]))
    |> Enum.reduce(
      {:ok, []},
      fn
        {:ok, i}, {:ok, acc} -> {:ok, [i | acc]}
        _, _acc -> {:error, :parse_result_item}
      end
    )
  end

  defp parse_response({:ok, %ExDeltaExchange.JsonResponse{success: false, error: error}}) do
    {:error, error}
  end
end
