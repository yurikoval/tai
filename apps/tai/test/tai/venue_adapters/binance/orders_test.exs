defmodule Tai.VenueAdapters.Binance.OrdersTest do
  use ExUnit.Case, async: false
  import Mock
  alias Tai.VenueAdapters.Binance.{CancelOrder, CreateOrder}

  @credentials %{api_key: "key", secret_key: "secret"}

  test "spot limit-maker orders use quantity without quoteOrderQty" do
    order = order(%{post_only: true, product_type: :spot})

    with_mock ExBinance.Rest.SpotClient,
      post: fn path, params, _credentials ->
        send(self(), {:request, path, params})
        {:ok, %{"orderId" => 42, "transactTime" => 1_700_000_000_000}}
      end do
      assert {:ok, response} = CreateOrder.create_order(order, @credentials, :spot)
      assert response.id == "42"

      assert_receive {:request, "/api/v3/order", params}
      assert params.type == "LIMIT_MAKER"
      assert params.quantity == "2.5"
      refute Map.has_key?(params, :quoteOrderQty)
      refute Map.has_key?(params, :timeInForce)
    end
  end

  test "USD-M close orders are reduce-only and post-only uses GTX" do
    order = order(%{close: true, post_only: true, product_type: :swap})

    with_mock ExBinance.Rest.UsdMarginFuturesClient,
      post: fn path, params, _credentials ->
        send(self(), {:request, path, params})
        {:ok, %{"orderId" => 43, "updateTime" => 1_700_000_000_000}}
      end do
      assert {:ok, response} =
               CreateOrder.create_order(order, @credentials, :usd_margin_futures)

      assert response.id == "43"
      assert_receive {:request, "/fapi/v1/order", params}
      assert params.timeInForce == "GTX"
      assert params.reduceOnly == "true"
    end
  end

  test "COIN-M cancellation uses the derivative endpoint" do
    order = order(%{venue_order_id: "44", product_type: :future})

    with_mock ExBinance.Rest.CoinMarginFuturesClient,
      delete: fn path, params, _credentials ->
        send(self(), {:request, path, params})
        {:ok, %{"orderId" => 44}}
      end do
      assert {:ok, response} =
               CancelOrder.cancel_order(order, @credentials, :coin_margin_futures)

      assert response.id == "44"
      assert_receive {:request, "/dapi/v1/order", %{orderId: "44", symbol: "BTCUSDT"}}
    end
  end

  defp order(overrides) do
    struct!(
      Tai.Orders.Order,
      Map.merge(
        %{
          client_id: "client-id",
          close: false,
          post_only: false,
          price: Decimal.new("100.25"),
          product_type: :spot,
          qty: Decimal.new("2.5"),
          side: :buy,
          time_in_force: :gtc,
          type: :limit,
          venue_order_id: nil,
          venue_product_symbol: "BTCUSDT"
        },
        overrides
      )
    )
  end
end
