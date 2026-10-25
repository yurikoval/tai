defmodule ExDeltaExchange.Products.List do
  alias ExDeltaExchange.Product

  @type product :: ExDeltaExchange.Product.t()
  @type result :: {:ok, [product]} | {:error, :parse_result_item}

  @spec get() :: result
  def get do
    "/products"
    |> ExDeltaExchange.HTTPClient.get(%{})
    |> parse_response()
  end

  defp parse_response({:ok, %ExDeltaExchange.JsonResponse{success: true, result: products}}) do
    products
    |> Enum.map(fn raw_product ->
      case map_to_struct(raw_product, Product) do
        {:ok, product} -> embed_map_to_struct(product)
        {:error, _} = error -> error
      end
    end)
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

  defp map_to_struct(map, mod) do
    Mapail.map_to_struct(map, mod, transformations: [:snake_case])
  end

  defp embed_map_to_struct(product) do
    product
    |> (fn p ->
          case map_to_struct(p.underlying_asset, Product.Asset) do
            {:ok, f} -> {:ok, %{p | underlying_asset: f}}
            {:error, _} = error -> error
          end
        end).()
    |> (fn
          {:ok, p} ->
            case map_to_struct(p.quoting_asset, Product.Asset) do
              {:ok, f} -> {:ok, %{p | quoting_asset: f}}
              {:error, _} = error -> error
            end

          {:error, _} = error ->
            error
        end).()
    |> (fn
          {:ok, %_{settling_asset: nil} = p} ->
            {:ok, p}

          {:ok, p} ->
            case map_to_struct(p.settling_asset, Product.Asset) do
              {:ok, f} -> {:ok, %{p | settling_asset: f}}
              {:error, _} = error -> error
            end

          {:error, _} = error ->
            error
        end).()
  end
end
