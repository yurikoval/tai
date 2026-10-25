defmodule Tai.Venues.Adapters.CreateOrderErrorTest do
  use Tai.TestSupport.DataCase, async: false
  use ExVCR.Mock, adapter: Tai.Test.ExVCRHackney

  setup_all do
    HTTPoison.start()
  end

  Tai.TestSupport.Helpers.test_venue_adapters_create_order_error_size_too_small()
  |> Enum.map(fn venue ->
    @venue venue

    setup do
      {:ok, _} = Tai.Venues.VenueStore.put(@venue)
      :ok
    end

    test "#{venue.id} size too small" do
      order = build_order(@venue.id, :buy, :gtc, action: :size_too_small)

      use_cassette "venue_adapters/shared/orders/#{@venue.id}/create_order_size_too_small" do
        assert {:error, reason} = Tai.Venues.Client.create_order(order)
        assert reason == :size_too_small
      end
    end
  end)

  Tai.TestSupport.Helpers.test_venue_adapters_create_order_error_insufficient_balance()
  |> Enum.map(fn venue ->
    @venue venue

    setup do
      {:ok, _} = Tai.Venues.VenueStore.put(@venue)
      :ok
    end

    test "#{venue.id} insufficient balance" do
      order = build_order(@venue.id, :buy, :gtc, action: :insufficient_balance)

      use_cassette "venue_adapters/shared/orders/#{@venue.id}/create_order_insufficient_balance" do
        assert {:error, reason} = Tai.Venues.Client.create_order(order)
        assert reason == :insufficient_balance
      end
    end
  end)

  defp build_order(venue_id, side, time_in_force, opts) do
    venue = venue_id |> Atom.to_string()
    action = Keyword.fetch!(opts, :action)
    post_only = Keyword.get(opts, :post_only, false)

    struct(Tai.Orders.Order, %{
      client_id: Ecto.UUID.generate(),
      venue: venue,
      credential: "main",
      product_symbol: venue |> product_symbol,
      product_type: venue |> product_type,
      side: side,
      price: venue |> price(side, time_in_force, action),
      qty: venue |> qty(side, time_in_force, action),
      type: :limit,
      time_in_force: time_in_force,
      post_only: post_only
    })
  end

  defp product_symbol("okex_futures"), do: "eth_usd_190510"
  defp product_symbol("okex_swap"), do: "eth_usd_swap"
  defp product_symbol(_), do: "ltc_btc"

  defp product_type("okex_swap"), do: :swap
  defp product_type(_), do: :future

  defp price("okex_futures", :buy, :gtc, :insufficient_balance), do: Decimal.new("140.5")
  defp price("okex_swap", :buy, :gtc, :insufficient_balance), do: Decimal.new("140.5")
  defp price(_, :buy, _, _), do: Decimal.new("0.007")

  defp qty("okex_futures", :buy, _, _), do: Decimal.new(5)
  defp qty("okex_swap", :buy, _, _), do: Decimal.new(5)
  defp qty(_, :buy, :gtc, :size_too_small), do: Decimal.new("0.000001")
  defp qty(_, :buy, :gtc, :insufficient_balance), do: Decimal.new(1_000)
  defp qty(_, :buy, _, _), do: Decimal.new("0.2")
end
