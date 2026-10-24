defmodule Tai.VenueAdapters.Binance.ErrorTest do
  use ExUnit.Case, async: true
  alias Tai.VenueAdapters.Binance.Error

  test "normalizes ambiguous order codes only for specific messages" do
    assert Error.normalize(
             {:error,
              {:binance_error,
               %{
                 "code" => -2010,
                 "msg" => "Account has insufficient balance for requested action."
               }}}
           ) == {:error, :insufficient_balance}
  end

  test "preserves ambiguous Binance order errors as unhandled" do
    crossing_order =
      {:binance_error, %{"code" => -2010, "msg" => "Order would immediately match and take."}}

    conflicting_reduce_only =
      {:binance_error,
       %{
         "code" => -2022,
         "msg" => "ReduceOnly Order is rejected because of existing open orders."
       }}

    assert Error.normalize({:error, crossing_order}) ==
             {:error, {:unhandled, crossing_order}}

    assert Error.normalize({:error, conflicting_reduce_only}) ==
             {:error, {:unhandled, conflicting_reduce_only}}
  end
end
